# README

## Setup

### Kubernetes and KEDA Version Compatibility

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
   For example, you can use port-forward to access Grafana. However, do not use port-forward for the boutique.

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

# Cluster Setup

- In a single cluster, set up the smart-scaler and your application. Expose the services as needed.

Once you have the setup working, it is recommended to enable xtrace for debugging:

Docker Repository
The first argument ($1) of the bash script should be the URL of your Docker repository. For example, if you have a local repository named foobar, pass it as a parameter:

Note
The initial part of the setup involves configuring what you already have with the correct versions. If you already have the necessary setup, you can skip this part.
