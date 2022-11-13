# Helm chart

- Set the right values in `values.yaml`. You should definitely change `mlfow_server_image.repository` and `mlfow_server_image.tag`.

- We assume that you are using the right kubernetes context. In the `helm` directory execute:
  ```shell
  helm lint mlflow
  helm install mlflow --debug --dry-run --namespace mlflow mlflow
  helm install mlflow --namespace mlflow mlflow
  ```
- If we are using `LoadBalancer` type of service we will get the following message:
  ```shell
  1. Get the application URL by running these commands:
  NOTE: It may take a few minutes for the LoadBalancer IP to be available.
    You can watch the status of by running 'kubectl get --namespace mlflow svc -w mlflow'
  
  export SERVICE_IP=$(kubectl get svc --namespace mlflow mlflow --template "{{ range (index .status.loadBalancer.ingress 0) }}{{.}}{{ end }}")
  
  echo http://$SERVICE_IP:8080
  ```
- You can always update the chart and create a new release:
  ```shell
  helm list --namespace mlflow
  helm upgrade mlflow --namespace mlflow mlflow
  ```
- Destroy everything with:
  ```shell
  helm uninstall mlflow --namespace mlflow
  ```
