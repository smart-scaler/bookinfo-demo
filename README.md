# Setup

🚀 Ensure cluster autoscaling (adding/deleting of the nodes) is turned on, to accommodate variable load traffic.
<br>
📦 Ensure the nodes have enough capacity.
<br>
🎯 Ensure that Prometheus is configured to scrape data from pushgateway and istio (as a target source)

Sample code is included in install.sh for your reference.

```python
# Check if Istio metrics are available in Prometheus
# change the prometheus url if needed
prometheus_url="http://localhost:9090/api/v1/query"
istio_metric_query='istio_request_duration_seconds_sum'
response=$(curl -s "$prometheus_url" --data-urlencode "query=$istio_metric_query")

if [[ $response == *"data"* ]]; then
 echo "Istio metrics are available in Prometheus."
else
 echo "Istio metrics are not available in Prometheus."
fi

# Check if Pushgateway is a target source in Prometheus
# change the prometheus url if needed
prometheus_targets_url="http://localhost:9090/api/v1/targets"
targets=$(curl -s "$prometheus_targets_url")

if [[ $targets == *"pushgateway"* ]]; then
 echo "Pushgateway is a target source in Prometheus."
else
 echo "Pushgateway is not a target source in Prometheus."
fi
```

<br>
🔗 Change the prometheus and pushgw urls in override config file located at https://github.com/smart-scaler/bookinfo-demo/blob/main/files/override_config.json

```json
"database": {
                            "name": "prometheus",
                            "url": "http://prometheus-stack-kube-prom-prometheus.monitoring.svc.cluster.local:9090",
                            "saas": false
                        },
```

<br>
🔗 Change the image name in smartscaler-inference.yaml to point to appropriate repo

<br>
🔗 Ensure that the smart-scaler image's digest is the same as the one mentioned below.

```yaml
docker images --digests | grep "fcd5f027a3026da320095238504fa362437aa146f6b3618731c1ed224816ef9b"
aveshasystems/smart-scaler   v0.6.1    sha256:fcd5f027a3026da320095238504fa362437aa146f6b3618731c1ed224816ef9b   63f9d6629b3b   3 hours ago    5.49GB
```

🚀 Run the install.sh script to setup the cluster with smart-scaler or HPA.

```bash
bash ./install.sh
```

🔗 demo-xtrace.log can be used as a reference to see the logs of the demo.

## Cluster Setup

🖥️ Reference Spec:

- CPU: 4CPU
- Ephemeral Storage: 52,416,492Ki
- Memory: 16,181,724Ki
- Pods: 58
- node.kubernetes.io/instance-type=t3.xlarge

📊 Allocatable:

- CPU: 3920 mCPU
- Ephemeral Storage: 47,233,329,7124
- Memory: 15,164,892Ki
- Pods: 58
- node.kubernetes.io/instance-type=t3.xlarge

## Kubernetes and KEDA Version Compatibility

Choose the KEDA version based on your Kubernetes (eks/k8s) version:

| KEDA  | Kubernetes    |
| ----- | ------------- |
| v2.11 | v1.25 - v1.27 |
| v2.10 | v1.24 - v1.26 |
| v2.9  | v1.23 - v1.25 |
| v2.8  | v1.17 - v1.25 |
| v2.7  | v1.17 - v1.25 |

For Kubernetes v1.27, install KEDA using Helm:

```bash
helm install keda kedacore/keda --namespace keda --version 2.11
```

## Grafana

Grafana is used for monitoring. It has two points of access:

1. To feed data into Grafana.
2. To access Grafana to visualize the data.
   For example, you can use port-forward to access Grafana. However, do not use port-forward for the bookinfo.

### Grafana Datasource Setup

1. Click on the gear icon on the left side of the screen.
2. Click on Add data source.
3. Select Prometheus.
4. Enter the URL of the Prometheus server. For example, http://prometheus-server.monitoring.svc.cluster.local:80.
5. click on Save & Test

![Image Description](./files/add-data-source.png)

### Grafana Dashboard Setup

1. Click on the 4square icon on the left side of the screen.
2. Select + Import.
   ![Image Description](./files/import-dashboard.png)
3. Upload the Smart_Scaler_Dashboard.json file from the files directory.
   ![Image Description](./files/upload_dashboard.png)

## Script Notes

- Have 1 cluster to setup Bookinfo HPA and another cluster with Smart-scaler.
- In the Script, there is an option to setup the cluster with Smart-scaler.
  `Do you want to continue with the installation of smart-scaler? (yes/no)`
- If you choose yes, then it will install the smart-scaler in the cluster.
- If you choose no, it will deploy with HPA
- Loadgenerator pod will automatically start traffic to the bookinfo deployments in the same cluster
