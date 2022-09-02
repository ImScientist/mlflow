# mlflow on Kubernetes

Setup mlflow server on Kubernetes with PostgreSQL DB (Google cloud) as backend and Google cloud storage as artifact
storage.

![Architecture](mlflow.png)

### Deployment with terraform

- Install the `terraform` version manager. We will work with version `1.2.7`:
  ```shell
  tfenv install 1.2.7
  tfenv use 1.2.7
  ```

- Set the `project`, `region` and `zone` in `variables.tf` and authenticate:
  ```shell
  gcloud init
  gcloud auth application-default login
  ```
  The following command will create the required infrastructure (backend db, cloud storage, kubernetes cluster and service accounts). It will also create the namespace `mlflow` and add to it a config-map and a secret with all relevant credentials for the service.
  ```shell
  terraform init
  terraform apply
  ```
- To deploy the service, we have to build the mlflow-server image and push it to the gcr container registry of our project:
  ```shell
  export TAG_NAME=1.0.0

  gcloud builds submit mlflow_server \
    --config mlflow_server/cloudbuild.yaml \
    --substitutions=TAG_NAME=$TAG_NAME
  ```
- Update the image name of the `mlflow-server-container` in `kubernetes/mlflow.yaml` to `gcr.io/${PROJECT_ID}/mlflow:${TAG_NAME}` (line 21). Change the kubectl context to the one of the newly created cluster and create the missing resources in the cluster:
  ```shell
  gcloud container clusters get-credentials < cluster_name > --zone  < zone > --project < project_id >
  
  kubectl -n mlflow create -f kubernetes/mlflow.yaml
  ```



### Create infrastructure

You have to create the following resources in Google cloud:

- Bucket in cloud storage that will be used as artifact storage
- PostreSQL DB in cloud SQL
- Container registry (GCR) with the mlflow image defined in `mlflow_server/Dockerfile`
- Service account (and json-key) with access to GCS and cloud SQL
- Service account (and json-key) with access to GCR (necessary only flor local tests)

You can create them with `./create_infra.sh`. To run the script below you need to
have [gsutil](https://cloud.google.com/storage/docs/gsutil), [gcloud](https://cloud.google.com/sdk/gcloud)
and [OpenSSL]() CLIs installed.

```shell
# Setup environment variables
echo """
  export REGION=europe-west3
  export TAG_NAME=1.0.0
  export BUCKET_NAME="artifacts-$(openssl rand -hex 12)"
  export SQL_INSTANCE_NAME=mlflow-backend
  export SQL_PWD=$(openssl rand -hex 12)
  
  # locations of all credentials
  export GCS_CREDENTIALS=".mlflow_credentials/gcs-access.json"
  export CSQL_CREDENTIALS=".mlflow_credentials/csql-access.json"
  export GCR_CREDENTIALS=".mlflow_credentials/gcr-access.json"
""" > .env

source .env

# gcloud configuration
gcloud init

# Create infrastructure
chmod +x create_infra.sh
./create_infra.sh
```

### Kubernetes deployment

You have to create the following kubernetes components:

- Kubernetes Secret that holds the sensitive access credentials to the cloud resources
- Kubernetes Configmap that holds project-dependent environment variables
- Kubernetes Deployment where each pod holds two containers:
    - cloud sql auth proxy container that creates a secure connection to the PostgreSQL DB
    - mlflow server that connects to the PostgreSQL DB via the cloud sql auth proxy

To achieve this we have to update the image name of the `mlflow-server-container` in `kubernetes/mlflow.yaml`
to `gcr.io/${PROJECT_ID}/mlflow:${TAG_NAME}`:

You can test the service with Docker Desktop or deploy it on a Kubernetes cluster in Google cloud:

- For local deployment you have to:
    - check that you are using the `docker-desktop` context


- For a deployment on a Kubernetes cluster in Google cloud you have to:
    - check that you are using the right context. You can switch to the right one by executing:
      ```shell
      gcloud container clusters get-credentials < cluster_name > \
          --zone  < zone > \
          --project < project_id >
      ```
    - create the cluster manually (I cannot automate that part yet)
    - get static IP (not yet done) and limit the unauthorized access (not yet done)

In both cases execute:

```shell
chmod +x kubernetes.sh

# local deployment 
./kubernetes.sh local

# gcloud deployment
./kubernetes.sh gcloud
```

To test if the Mflow server is running you can run the experiment `python test/train.py` and verify that the results are
logged in `localhost:8080`. In the experiment definition you will see that we are using the `GCS_CREDENTIALS` to store
the artifacts in GCS.

### Resources

[Using Google Container Registry (GCR) with Kubernetes](https://colinwilson.uk/2020/07/09/using-google-container-registry-with-kubernetes/)
