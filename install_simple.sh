# Readme:
# 1. Ensure cluster autoscaling (adding/deleting of the nodes) is turned on, to accommodate variable load traffic.
# 📦 2. Ensure the nodes have enough capacity.
# 🔧 3. Install keda based on your eks/k8s version.
#    KEDA   Kubernetes
#    v2.11  v1.25 - v1.27
#    v2.10  v1.24 - v1.26
#    v2.9   v1.23 - v1.25
#    v2.8   v1.17 - v1.25
#    v2.7   v1.17 - v1.25
#    For k8s v1.27, use: helm install keda kedacore/keda --namespace keda --version 2.11
# 🔀 4. Include examples to port-forward Grafana svc. For example: kubectl port-forward svc/grafana 3000:3000 -n grafana
# 🎯 5. Ensure that Prometheus is configured to scrape data from pushgateway and istio (as a target source)
# 6. Change the prometheus and pushgw urls in override config file
# 🖥️ Required Spec:
#   - CPU: 4
#   - Ephemeral Storage: 52,416,492Ki
#   - Memory: 16,181,724Ki
#   - Pods: 58
#   - node.kubernetes.io/instance-type=t3.xlarge

# 📊 Allocatable:
#   - CPU: 3920m
#   - Ephemeral Storage: 47,233,329,7124
#   - Memory: 15,164,892Ki
# - Pods: 58
# - node.kubernetes.io/instance-type=t3.xlarge
#!/bin/bash

set -o xtrace

# Might not be needed for local repo
DOCKER_USER="<docker-username>"
DOCKER_PASS="<docker-password>"

echo "======== Installing demo environment... k8s, istio, prometheus ============="

curl -sL https://istio.io/downloadIstioctl | sh -
export PATH=$PATH:$HOME/.istioctl/bin
istioctl x precheck
istioctl install -y

if kubectl wait --for=condition=Ready pod -n istio-system -l app=istiod --timeout=5m; then
    echo "Istio installation successful"
    echo "Getting the pods in istio-system"
else
    echo "Istio installation failed$"
    exit 1
fi

kubectl get pods -n istio-system

kubectl create namespace monitoring
helm install prometheus-pushgateway prometheus-community/prometheus-pushgateway -n monitoring --version 2.4.1
helm install prometheus-stack -n monitoring ./kube-prometheus-stack/

if kubectl wait --for=condition=Ready pod -n monitoring -l app.kubernetes.io/instance=prometheus-stack-kube-prom-prometheus --timeout=5m; then
    echo "Prometheus installation successful$"
else
    echo "Prometheus installation failed$"
    exit 1
fi


read -p "Do you want to install keda? (y/N): " INSTALL_KEDA
if [ "$INSTALL_KEDA" = "y" ] || [ "$INSTALL_KEDA" = "Y" ]; then
    helm repo add kedacore https://kedacore.github.io/charts
    helm repo update kedacore
    kubectl create namespace keda
    helm install keda kedacore/keda --namespace keda
fi


SERVICE_INFO=$(kubectl get svc prometheus-stack-kube-prom-prometheus -n monitoring -o=json)
PROMETHEUS_EXTERNAL_IP=$(echo "$SERVICE_INFO" | jq -r '.status.loadBalancer.ingress[0].hostname')
PROMETHEUS_PORT=$(echo "$SERVICE_INFO" | jq -r '.spec.ports[0].port')

if kubectl wait --for=condition=Ready pod -n monitoring -l app.kubernetes.io/name=grafana --timeout=5m; then
    echo "Grafana installation successful"
else
    echo "Grafana installation failed"
    exit 1
fi


# Use kubectl to get the Prometheus service information
SERVICE_INFO=$(kubectl get svc prometheus-stack-grafana -n monitoring -o=json)

# Extract the external IP and port
GRAFANA_EXTERNAL_IP=$(echo $SERVICE_INFO | jq -r '.status.loadBalancer.ingress[0].hostname')
GRAFANA_PORT=$(echo $SERVICE_INFO | jq -r '.spec.ports[0].port')


# add code to check if istio metric is working on prometheus
# code to check if pushgw is a target source on prometheus

# install metrics server
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
kubectl apply -f ./files/prom-dataplane.yaml -n monitoring
kubectl apply -f ./files/prom-controlplane.yaml -n monitoring

echo "======== Installing demo app... bookinfo and locust traffic generator ============"


echo "Creating new namespace demo"
kubectl create ns demo

echo "Labeling namespace demo with istio-injection=enabled"
kubectl label namespace demo istio-injection=enabled --overwrite

echo "Installing bookinfo application "

# helm install boutique ./chart-boutique
echo "Installing bookinfo app..."
kubectl apply -f ./files/bookinfo.yaml -n demo

echo "Starting load for bookinfo app ..."
kubectl apply -f ./files/bookinfo-loadgen.yaml -n demo

echo "Waiting for bookinfo app to come up..."

echo "Check if all pods are running with 2 containers"
kubectl -n demo wait --for=condition=Ready pod --all

echo "Applying HPA for bookinfo app..."
kubectl apply -f ./files/bookinfo-cpu-hpa.yaml -n demo

echo "Waiting for bookinfo app to scale..."
sleep 120

echo "Do you want to continue with the installation of smart-scaler? (yes/no)"
read user_input

if [ "$user_input" != "yes" ] && [ "$user_input" != "y" ]; then
    echo "Installation of smart-scaler cancelled."
    exit 1
fi

echo "======== Installing smart scaler to manage bookinfo ================="

echo "Creating namespace smart-scaler..."
kubectl create ns smart-scaler

echo "Creating docker registry secret..."
# Comment out the below line if local repo doesn't require a pull secret
kubectl create secret docker-registry avesha-docker --namespace smart-scaler --docker-username=${DOCKER_USER} --docker-password=${DOCKER_PASS}

echo "Creating configmap from file..."
kubectl create configmap config-override --from-file=files/override_config.json -n smart-scaler

echo "Applying smartscaler-inference.yaml..."
kubectl -n smart-scaler apply -f ./files/smartscaler-inference.yaml

echo "Switching from autoscaling to smart-scaler..."
kubectl -n demo apply -f ./files/rl-keda.yaml

echo "Prometheus URL is http://$PROMETHEUS_EXTERNAL_IP:$PROMETHEUS_PORT"
echo "Grafana URL is http://$GRAFANA_EXTERNAL_IP:$GRAFANA_PORT"
echo "Default Username and Password is admin, please visit the URL and change it."

echo "Installation complete!"
