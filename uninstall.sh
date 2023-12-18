set -x


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


echo "🔐 Deleting docker registry secret..."
kubectl delete secret avesha-docker -n smart-scaler

echo "🗑️ Deleting configmap..."
kubectl delete configmap config-override -n smart-scaler

echo "📂 Deleting smartscaler-inference.yaml..."
kubectl delete -f ./files/smartscaler-inference.yaml -n smart-scaler

echo "🚧 Deleting namespace smart-scaler..."
kubectl delete ns smart-scaler

echo "📂 Deleting frontend-rl.yaml..."
kubectl delete -f ./files/frontend-rl.yaml -n demo

echo "📂 Deleting cart-rl.yaml..."
kubectl delete -f ./files/cart-rl.yaml -n demo

echo "📂 Deleting currency-rl.yaml..."
kubectl delete -f ./files/currency-rl.yaml -n demo

echo "📂 Deleting productcatalogue-rl.yaml..."
kubectl delete -f ./files/productcatalogue-rl.yaml -n demo

echo "📂 Deleting checkout-rl.yaml..."
kubectl delete -f ./files/checkout-rl.yaml -n demo

echo "📂 Deleting recommendation-rl.yaml..."
kubectl delete -f ./files/recommendation-rl.yaml -n demo


kubectl delete -f ./files/boutique-app.yaml -n demo


echo "🚧 Deleting namespace demo..."
kubectl delete ns demo

echo "📦 Uninstalling grafana..."
helm uninstall grafana -n monitoring

echo "📦 Uninstalling prometheus-pushgateway..."
helm uninstall prometheus-pushgateway -n monitoring

echo "📦 Uninstalling prometheus..."
helm uninstall prometheus -n monitoring

echo "📦 Uninstalling prometheus-stack..."
helm uninstall prometheus-stack -n monitoring

echo "🚧 Deleting namespace monitoring..."
kubectl delete ns monitoring

echo "📦 Uninstalling keda..."
helm uninstall keda -n keda

echo "🚧 Deleting namespace keda..."
kubectl delete ns keda


istioctl uninstall --purge

echo "🚧 Deleting namespace istio-system..."
kubectl delete ns istio-system


set +x