# mlflow on Kubernetes

Setup mlflow server on Kubernetes with PostgreSQL DB (Google cloud) as backend and Google cloud storage as artifact
storage.

![Architecture](mlflow.png)

### Infrastructure

We will create the following resources in Google cloud:

- Bucket in cloud storage that will be used as artifact storage
- PostreSQL DB in cloud SQL that will be used as mlflow backend db
- Container registry (GCR) that will host the mlflow image defined in `mlflow_server/Dockerfile`
- Service account (and json-key) with access to GCS and cloud SQL
- Service account (and json-key) with access to GCR (used by the Google node pool to pull images from GCR)

The kubernetes cluster contains:

- Kubernetes Secret that contains credentials of the service account with GCS and SQL access, as well as access to the backend db
- Kuberentes Configmap
- Kubernetes Deployment where each pod holds two containers:
    - cloud sql auth proxy container that creates a secure connection to the PostgreSQL DB
    - mlflow server that connects to the PostgreSQL DB via the cloud sql auth proxy. We use a custom build image that is defined in `./mlflow_server`
- Kubernetes Service


### Deployment with terraform


- Install the `terraform` version manager. We will work with version `1.2.7`:
  ```shell
  tfenv install 1.2.7
  tfenv use 1.2.7
  ```


- Set the `project`, `region` and `zone` in `./terrafrom/variables.tf` and authenticate:
  ```shell
  gcloud init
  gcloud auth application-default login
  ```
  The following command will create the required infrastructure (backend db, cloud storage, kubernetes cluster and service accounts). It will also create the namespace `mlflow` and add to it a config-map and a secret with all relevant credentials for the service.
  ```shell
  # in the ./terraform directory
  terraform init
  terraform apply
  ```


- To deploy the service, we first have to build a mlflow-server image (content in `./mlflow_server` directory) and push it to the container registry in our project. We will use Google cloud build:
  ```shell
  # Docker image tag
  export TAG_NAME=1.0.0
  export PROJECT_ID=$(gcloud config list --format='value(core.project)')

  gcloud builds submit mlflow_server \
    --config mlflow_server/cloudbuild.yaml \
    --substitutions=TAG_NAME=$TAG_NAME
  ```
  As a result the image `gcr.io/${PROJECT_ID}/mlflow:${TAG_NAME}` should be created.
  

- The remaining components that have to be created are described in `kubernetes/mlflow.yaml`. We have to change the image of the `mlflow-server-container` (line 21) to point to the image that we have created in the previous step. We can use `kubectl` to crete the missing components:
  ```shell
  # change the kubectl context (gcc-mlflow: name of the container cluster)
  gcloud container clusters get-credentials gcc-mlflow \
    --zone  < zone > \
    --project < project_id >

  kubectl -n mlflow create -f kubernetes/mlflow.yaml
  ```



### Deployment without terraform

We will rely on the Google cloud SDK to create the resources of interest. To run the commands below you need to have [gsutil](https://cloud.google.com/storage/docs/gsutil), [gcloud](https://cloud.google.com/sdk/gcloud)
and [OpenSSL]() CLIs installed.

- Setup environment variables:
  ```shell
  # Setup environment variables
  echo """
    export REGION=europe-west3
    export TAG_NAME=1.0.0
    export BUCKET_NAME="artifacts-$(openssl rand -hex 12)"
    export SQL_INSTANCE_NAME=mlflow-backend
    export SQL_PWD=$(openssl rand -hex 12)
    
    # locations where some credentials will be stored
    export MLFLOW_CREDENTIALS=".mlflow_credentials/gcs-csql-access.json"
    export GCR_CREDENTIALS=".mlflow_credentials/gcr-access.json"
  """ > .env
  
  source .env
  
  chmod +x kubernetes.sh
  chmod +x create_infra.sh
  ```

- Create the required resources in Google cloud (except the kubernetes cluster):
  ```shell
  # gcloud configuration
  gcloud init
  
  # Create infrastructure
  ./create_infra.sh
  ```
  Unfortunately, I am not able to create a kubernetes cluster with the gcloud sdk so you have to use the UI to create it.
  
- Creation of the Kubernetes cluster components. You have to change the kubectl context:
  ```shell
  gcloud container clusters get-credentials < container cluster name > \
    --zone  < zone > \
    --project < project_id >
  
  # gcloud deployment
  ./kubernetes.sh gcloud  
  ```
  If you have looked at the last shell script you will see that there is an option for local deployment with `docker-descktop`:
  ```shell
  # switch kubectl context
  kubectl config use-context docker-desktop
  
  # local deployment 
  ./kubernetes.sh local
  ```

- Test if everything works:  
To test if the Mflow server is running you can run the experiment `python test/train.py` and verify through the mlflow UI that the results are logged. In the experiment definition you will see that we are using the `GCS_CREDENTIALS` to store the artifacts in GCS.

### Resources

[Using Google Container Registry (GCR) with Kubernetes](https://colinwilson.uk/2020/07/09/using-google-container-registry-with-kubernetes/)
