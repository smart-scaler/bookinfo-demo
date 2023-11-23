#!/bin/bash

# set -o xtrace

echo "🚀 1. Make sure cluster autoscaling (adding/deleting of the nodes) is turned on, to accommodate variable load traffic."
echo "📦 2. Make sure the nodes have enough capacity."
echo "🔧 3. Install keda based on your eks/k8s version."
echo "   KEDA   Kubernetes"
echo "   v2.11  v1.25 - v1.27"
echo "   v2.10  v1.24 - v1.26"
echo "   v2.9   v1.23 - v1.25"
echo "   v2.8   v1.17 - v1.25"
echo "   v2.7   v1.17 - v1.25"
echo "   For k8s v1.27, use: helm install keda kedacore/keda --namespace keda --version 2.11"
echo "🔀 4. Include examples to port-forward Grafana svc. For example: kubectl port-forward svc/grafana 3000:3000 -n grafana"
echo "🎯 5. Make sure that Prometheus is configured to scrape data from pushgateway and istio (as a target source)"
echo "🔗 6. Change the prometheus and pushgw urls in override config file"
echo "🔗 7. Please ensure to change the image name in smartscaler-inference.yaml"

echo -e "🖥️ Capacity:
  - CPU: 4
  - Ephemeral Storage: 52,416,492Ki
  - Memory: 16,181,724Ki
  - Pods: 58
  - node.kubernetes.io/instance-type=t3.xlarge

📊 Allocatable:
  - CPU: 3920m
  - Ephemeral Storage: 47,233,329,7124
  - Memory: 15,164,892Ki
  - Pods: 58
- node.kubernetes.io/instance-type=t3.xlarge"


GREEN=$(tput setaf 2)
RED=$(tput setaf 1)
RESET=$(tput sgr0)

DOCKER_USER="<docker-username>"
DOCKER_PASS="<docker-password>"


function switch_context_with_kubectx() {
    read -p "Please enter the kubecontext: " KUBECONTEXT
    echo "🔄 Using kubectx to switch contexts..."
    kubectx $KUBECONTEXT
    echo -e "${GREEN}🌐 KUBECONFIG set to: $KUBECONTEXT${RESET}"
}

function switch_context_with_kubeconfig_path() {
    read -p "Please enter the path to your KUBECONFIG file: (n/N to continue with current context) " KUBECONFIG_PATH
    if [[ "${KUBECONFIG_PATH,,}" = "n" ]]; then
        echo "➡️ Continuing with the same context"
    else
        export KUBECONFIG="$KUBECONFIG_PATH"
        echo -e "${GREEN}🌐 KUBECONFIG set to: $KUBECONFIG${RESET}"
    fi
}

if [ -z "$KUBECONFIG" ]; then
    read -p "Do you want to use kubectx to switch contexts? (y/N): " USE_KUBECTX
    if [[ "${USE_KUBECTX,,}" = "y" ]]; then
        switch_context_with_kubectx
    else
        switch_context_with_kubeconfig_path
    fi
fi

echo -e "${RED}🔄 Switching to required context...${RESET}"

echo "${RED}⬇️ Downloading and installing istio${RESET}"

read -p "Do you want to install istio? (y/N): " INSTALL_ISTIO
if [[ "${INSTALL_ISTIO,,}" = "y" ]]; then
    curl -sL https://istio.io/downloadIstioctl | sh -
    export PATH=$PATH:$HOME/.istioctl/bin
    istioctl x precheck
    istioctl install -y
    
    if kubectl wait --for=condition=Ready pod -n istio-system -l app=istiod --timeout=5m; then
        echo "${RED}✅ Istio installation successful"
        echo "🔍 Getting the pods in istio-system${RESET}"
    else
        echo "${RED}❌ Istio installation failed${RESET}"
        exit 1
    fi
    kubectl get pods -n istio-system
fi

echo "${RED}⬇️ Installing Prometheus${RESET}"

read -p "Do you want to install prometheus? (y/N): " INSTALL_PROMETHEUS
if [[ "${INSTALL_PROMETHEUS,,}" = "y" ]]; then
    kubectl create namespace monitoring
    
    read -p "Please enter \"y\" if you want to install all the prometheus charts in 1 command and \"n\" if you want to install them individually: " ONESHOT_PROM
    if [[ "${ONESHOT_PROM,,}" = "y" ]]; then
        helm install prometheus-pushgateway prometheus-community/prometheus-pushgateway -n monitoring --version 2.4.1
        helm install prometheus-stack -n monitoring ./kube-prometheus-stack/
    else
        helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
        helm install prometheus-pushgateway prometheus-community/prometheus-pushgateway -n monitoring --version 2.4.1
        helm repo add grafana https://grafana.github.io/helm-charts
        helm install grafana grafana/grafana -n monitoring --version 6.5.3
        helm -n monitoring install prometheus prometheus-community/prometheus --version 24.5.0
    fi
    if kubectl wait --for=condition=Ready pod -n monitoring -l app.kubernetes.io/instance=prometheus-stack-kube-prom-prometheus --timeout=5m; then
        echo "${RED}✅ Prometheus installation successful${RESET}"
    else
        echo "${RED}❌ Prometheus installation failed${RESET}"
        exit 1
    fi
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
    echo "${RED}✅ Grafana installation successful${RESET}"
else
    echo "${RED}❌ Grafana installation failed${RESET}"
    exit 1
fi


SERVICE_INFO=$(kubectl get svc prometheus-stack-grafana -n monitoring -o=json)

# Extract the external IP and port
GRAFANA_EXTERNAL_IP=$(echo $SERVICE_INFO | jq -r '.status.loadBalancer.ingress[0].hostname')
GRAFANA_PORT=$(echo $SERVICE_INFO | jq -r '.spec.ports[0].port')


# Check if Istio metrics are available in Prometheus
prometheus_url="http://localhost:9090/api/v1/query"
istio_metric_query='istio_request_duration_seconds_sum'
response=$(curl -s "$prometheus_url" --data-urlencode "query=$istio_metric_query")

if [[ $response == *"data"* ]]; then
    echo "Istio metrics are available in Prometheus."
else
    echo "Istio metrics are not available in Prometheus."
fi

# Check if Pushgateway is a target source in Prometheus
prometheus_targets_url="http://localhost:9090/api/v1/targets"
targets=$(curl -s "$prometheus_targets_url")

if [[ $targets == *"pushgateway"* ]]; then
    echo "Pushgateway is a target source in Prometheus."
else
    echo "Pushgateway is not a target source in Prometheus."
fi

# install metrics server
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
kubectl apply -f ./files/prom-dataplane.yaml -n monitoring
kubectl apply -f ./files/prom-controlplane.yaml -n monitoring

echo "${RED}🔗 Creating new namespace demo${RESET}"
kubectl create ns demo

echo "${RED}🔗 Labeling namespace demo with istio-injection=enabled${RESET}"
kubectl label namespace demo istio-injection=enabled --overwrite

echo "${RED}🛠️ Installing bookinfo application ${RESET}"

# helm install boutique ./chart-boutique
echo "${RED}⏳ Installing bookinfo app...${RESET}"
kubectl apply -f ./files/bookinfo.yaml -n demo

echo "${RED}⏳ Starting load for bookinfo app ...${RESET}"
kubectl apply -f ./files/bookinfo-loadgen.yaml -n demo

echo "${RED}⏳ Waiting for bookinfo app to come up...${RESET}"

echo "${RED}🔍 Check if all pods are running with 2 containers${RESET}"
kubectl -n demo wait --for=condition=Ready pod --all

echo "${RED}⏳ Applying HPA for bookinfo app...${RESET}"
kubectl apply -f ./files/bookinfo-cpu-hpa.yaml -n demo

echo "${RED}⏳ Waiting for bookinfo app to scale...${RESET}"
sleep 120

echo "Do you want to continue with the installation of smart-scaler? (yes/no)"
read user_input

# If the user input is not 'yes' or 'y', then exit the script
if [ "$user_input" != "yes" ] && [ "$user_input" != "y" ]; then
    echo "Installation of smart-scaler cancelled."
    exit 1
fi

echo "🛠️ Creating namespace smart-scaler..."
kubectl create ns smart-scaler

echo "🔑 Creating docker registry secret..."
kubectl create secret docker-registry avesha-docker --namespace smart-scaler --docker-username=${DOCKER_USER} --docker-password=${DOCKER_PASS}

echo "📁 Creating configmap from file..."
kubectl create configmap config-override --from-file=files/override_config.json -n smart-scaler

echo "🚀 Applying smartscaler-inference.yaml..."
echo "⚠️ Please ensure to change the image name in smartscaler-inference.yaml before proceeding."
kubectl -n smart-scaler apply -f ./files/smartscaler-inference.yaml

# Add the grafana dashboard for HPA


echo "🚀 Switching from autoscaling to smart-scaler..."
kubectl -n demo apply -f ./files/rl-keda.yaml

echo "${RED}🔗 Prometheus URL is http://$PROMETHEUS_EXTERNAL_IP:$PROMETHEUS_PORT"
echo "🔗 Grafana URL is http://$GRAFANA_EXTERNAL_IP:$GRAFANA_PORT"
echo "🔑 Default Username and Password is admin, please visit the URL and change it.${RESET}"

echo "${GREEN}🎉 Installation complete!${RESET}"


echo "${RED}⏳ Starting load for bookinfo app ...${RESET}"
kubectl apply -f ./files/bookinfo-loadgen.yaml -n demo

echo "${RED}⏳ Waiting for bookinfo app to come up...${RESET}"

echo "${RED}🔍 Check if all pods are running with 2 containers${RESET}"
kubectl -n demo wait --for=condition=Ready pod --all

echo "${RED}⏳ Applying HPA for bookinfo app...${RESET}"
kubectl apply -f ./files/bookinfo-cpu-hpa.yaml -n demo

echo "${RED}⏳ Waiting for bookinfo app to scale...${RESET}"
sleep 120

echo "Do you want to continue with the installation of smart-scaler? (yes/no)"
read user_input

# If the user input is not 'yes' or 'y', then exit the script
if [ "$user_input" != "yes" ] && [ "$user_input" != "y" ]; then
    echo "Installation of smart-scaler cancelled."
    exit 1
fi

echo "🛠️ Creating namespace smart-scaler..."
kubectl create ns smart-scaler

echo "🔑 Creating docker registry secret..."
kubectl create secret docker-registry avesha-docker --namespace smart-scaler --docker-username=${DOCKER_USER} --docker-password=${DOCKER_PASS}

echo "📁 Creating configmap from file..."
kubectl create configmap config-override --from-file=files/override_config.json -n smart-scaler

echo "🚀 Applying smartscaler-inference.yaml..."
kubectl -n smart-scaler apply -f ./files/smartscaler-inference.yaml

# Add the grafana dashboard To visualize the application metrics

echo "🚀 Switching from autoscaling to smart-scaler..."
kubectl -n demo apply -f ./files/rl-keda.yaml

echo "${RED}🔗 Prometheus URL is http://$PROMETHEUS_EXTERNAL_IP:$PROMETHEUS_PORT"
echo "🔗 Grafana URL is http://$GRAFANA_EXTERNAL_IP:$GRAFANA_PORT"
echo "🔑 Default Username and Password is admin, please visit the URL and change it.${RESET}"

echo "${GREEN}🎉 Installation complete!${RESET}"