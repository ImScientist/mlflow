#!/usr/bin/env sh

echo """
####################################################################
# Create (locally) the following kubernetes (K) components:        #
#  - K-Secret that holds access credentials to the cloud resources #
#  - K-Configmap that holds project-dependent env variables        #
#  - K-Deployment where each pod holds two containers:             #
#     - cloud sql auth proxy that connects to the PostgreSQL DB    #
#     - mlflow server                                              #
####################################################################
"""

[ "$1" != "local" ] && [ "$2" != "gcloud" ] && echo "
No valid execution environment (local or gcloud) is provided!
Usage: ./kubernetes_local.sh local|gcloud
" && exit 1



kubectl create namespace mlflow



if [ "$1" == "local" ]; then
  echo """
  Configure local K-components to access images stored in GCR...
  """
  kubectl -n mlflow create secret docker-registry gcr-io-secret \
    --docker-server=gcr.io \
    --docker-username=_json_key \
    --docker-password="$(cat $GCR_CREDENTIALS)"

  # Patch the default service account with the imagePullSecrets configuration
  kubectl -n=mlflow patch serviceaccount default \
        -p '{"imagePullSecrets": [{"name": "gcr-io-secret"}]}'
fi



echo """
Create K-secret, K-configmap, ml-server deployment and service...
"""
kubectl -n mlflow create secret generic mlflow-secret \
  --from-file=csql-auth=$CSQL_CREDENTIALS \
  --from-file=gcs-auth=$GCS_CREDENTIALS \
  --from-literal=sql_usr=postgres \
  --from-literal=sql_pwd=$SQL_PWD \
  --from-literal=sql_db=postgres

kubectl -n mlflow create -f kubernetes/configmap.yaml

kubectl -n mlflow create -f kubernetes/mlflow.yaml
