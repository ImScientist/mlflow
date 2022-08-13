# mlflow on Kubernetes

Setup mlflow server with PostgreSQL DB (Google cloud) as backend and Google cloud storage as artifact storage.

### mlflow server

- Create a container that is running the mlflow server.
  ```shell
  docker build -t imscientist/mlflow:0.1 .

  docker run -it --rm --name mlflow_test -p 5000:5000 \
    imscientist/mlflow:0.1 /bin/bash -c "mlflow server --host 0.0.0.0"
  ```

### Kubernetes (local tests)

- Check that using the `docker-desktop` context
- Make sure that you can push images to the GCR:
    - initialize the gcloud account with `gcloud init`
    - update docker config with `gcloud auth configure-docker`
    - Push the mlflow server image to GCR (or use `cloudbuild)`:
      ```shell
      gcloud init
      gcloud auth configure-docker
      
      PROJECT_ID=$(gcloud config list project --format "value(core.project)")
      IMAGE_URI="eu.gcr.io/$PROJECT_ID/mlflow:0.1"
      
      docker build -f Dockerfile -t $IMAGE_URI .
      docker push $IMAGE_URI
      ```  

- Create the following resources in Google cloud:
    - Bucket in cloud storage that will be used as artifact storage
    - PostreSQL DB in cloud SQL
    - Service account (and json-key) with access to GCS
    - Service account (and json-key) with access to cloud SQL

  ```shell
  CLOUD_STORAGE_CREDENTIALS=/Users/ivanova/.gcs_credentials/development-env-ta_gcs-auth.json
  
  CLOUD_SQL_CREDENTIALS=/Users/ivanova/.gcs_credentials/development-env-ta_csql-auth.json

  # root user password and backed db  
  SQL_USR=postgres
  SQL_PWD=laJHP085BYbemhnBbTLUkijqP3sgyqoF
  SQL_DB=postgres
  ```

- Create the following kubernetes components:
    - Kubernetes Secret that holds the sensitive access credentials to the cloud resources
    - Kubernetes Configmap that holds project-dependent environment variables
    - Kubernetes Deployment where each pod holds two containers:
        - cloud sql auth proxy container that creates a secure connection to the PostgreSQL DB
        - mlflow server that connects to the PostgreSQL DB via the cloud sql auth proxy

  ```shell
    kubectl create secret generic mlflow-secret \
      --from-file=csql-auth=$GOOGLE_CLOUD_SQL_CREDENTIALS \
      --from-file=gcs-auth=$GOOGLE_APPLICATION_CREDENTIALS \
      --from-literal=sql_usr=$SQL_USR \
      --from-literal=sql_pwd=$SQL_PWD \
      --from-literal=sql_db=$SQL_DB
    
    kubectl create -f kubernetes/configmap.yaml
  
    kubectl create -f kubernetes/mlflow.yaml    
  ```
