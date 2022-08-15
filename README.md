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
      
      export PROJECT_ID=$(gcloud config list project --format "value(core.project)")
      export TAG_NAME=1.0.0
      IMAGE_URI="eu.gcr.io/{$PROJECT_ID}/mlflow:${TAG_NAME}"

      docker build -f mlflow_server/Dockerfile -t $IMAGE_URI mlflow_server
      docker push $IMAGE_URI
      
      # OR using cloudbuild
      gcloud builds submit mlflow_server \
        --config mlflow_server/cloudbuild.yaml \
        --substitutions=TAG_NAME=$TAG_NAME
      ```

- Create the following resources in Google cloud:
  - Bucket in cloud storage that will be used as artifact storage
  - PostreSQL DB in cloud SQL
  - Service account (and json-key) with access to GCS
  - Service account (and json-key) with access to cloud SQL
    ```shell
    gcloud init
    PROJECT_ID=$(gcloud config list --format='value(core.project)')
    PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format='value(projectNumber)')
    BUCKET_NAME="artifacts-${PROJECT_ID}"
    SQL_PWD=111222
    
    # Enable all relevant services
    gcloud services enable \
      container.googleapis.com \
      cloudbuild.googleapis.com \
      containerregistry.googleapis.com \
      sqladmin.googleapis.com \
      iam.googleapis.com
    
    gcloud services enable containerregistry.googleapis.com
    
    gsutil mb gs://$BUCKET_NAME
        
    INSTANCE_NAME=mlflow-backend
    REGION=europe-west3
    
    gcloud sql instances create $INSTANCE_NAME \
      --database-version=POSTGRES_9_6 \
      --tier db-f1-micro \
      --storage-size=10 \
      --region=europe-west3 \
      --root-password=$SQL_PWD
        
    acc_name=gcs-access
    gcloud iam service-accounts create ${acc_name}
    gcloud projects add-iam-policy-binding $PROJECT_ID \
      --member "serviceAccount:${acc_name}@${PROJECT_ID}.iam.gserviceaccount.com" \
      --role "roles/storage.admin"

    GCS_CREDENTIALS="$(echo ~)/.mlflow_credentials/${acc_name}.json"
    gcloud iam service-accounts keys create $GCS_CREDENTIALS \
      --iam-account=${acc_name}@${PROJECT_ID}.iam.gserviceaccount.com

    acc_name=csql-access
    gcloud iam service-accounts create ${acc_name}
    gcloud projects add-iam-policy-binding $PROJECT_ID \
      --member "serviceAccount:${acc_name}@${PROJECT_ID}.iam.gserviceaccount.com" \
      --role "roles/cloudsql.admin"

    CSQL_CREDENTIALS="$(echo ~)/.mlflow_credentials/${acc_name}.json"
    gcloud iam service-accounts keys create $CSQL_CREDENTIALS \
      --iam-account=${acc_name}@${PROJECT_ID}.iam.gserviceaccount.com
    
    acc_name=gcr-access
    gcloud iam service-accounts create ${acc_name}
    gcloud projects add-iam-policy-binding $PROJECT_ID \
      --member "serviceAccount:${acc_name}@${PROJECT_ID}.iam.gserviceaccount.com" \
      --role "roles/containerregistry.ServiceAgent"

    gcloud projects add-iam-policy-binding $PROJECT_ID \
      --member "serviceAccount:${acc_name}@${PROJECT_ID}.iam.gserviceaccount.com" \
      --role "roles/storage.admin"
    
    GCR_CREDENTIALS="$(echo ~)/.mlflow_credentials/${acc_name}.json"
    gcloud iam service-accounts keys create $GCR_CREDENTIALS \
      --iam-account=${acc_name}@${PROJECT_ID}.iam.gserviceaccount.com
    ```

- Create the following kubernetes components:
    - Kubernetes Secret that holds the sensitive access credentials to the cloud resources
    - Kubernetes Configmap that holds project-dependent environment variables
    - Kubernetes Deployment where each pod holds two containers:
        - cloud sql auth proxy container that creates a secure connection to the PostgreSQL DB
        - mlflow server that connects to the PostgreSQL DB via the cloud sql auth proxy

  - Update the key-value pairs in `kubernetes/configmap.yaml`:
    - artifacts_store_uri: `gs://${BUCKET_NAME}/artifacts`
    - sql_instance_connection_name: `${PROJECT_ID}:${REGION}:${INSTANCE_NAME}`

  - Update `kubernetes/mlflow.yaml`:
    - `spec.template.spec.containers[mlflow-server-container].image`: set the mlflow image location in the Google container registry
  ```shell
    # Make sure that you have set the right kubernetes context

    kubecctl create namespace mlflow
    
    # Configure Kubernetes to access images stored in GCR
    # Probably not relevant when the kubernetes cluster and container registry
    # are in the same project
    kubectl -n mlflow create secret docker-registry gcr-io-secret \
      --docker-server=gcr.io \
      --docker-username=_json_key \
      --docker-password="$(cat $GCR_CREDENTIALS)"

    # Patch the default service account with the imagePullSecrets configuration
    kubectl -n=mlflow patch serviceaccount default \
          -p '{"imagePullSecrets": [{"name": "gcr-io-secret"}]}'

    kubectl -n mlflow create secret generic mlflow-secret \
      --from-file=csql-auth=$CSQL_CREDENTIALS \
      --from-file=gcs-auth=$GCS_CREDENTIALS \
      --from-literal=sql_usr=postgres \
      --from-literal=sql_pwd=$SQL_PWD \
      --from-literal=sql_db=postgres

    kubectl -n mlflow create -f kubernetes/configmap.yaml

    kubectl -n mlflow create -f kubernetes/mlflow.yaml
  ```
  - To test if the Mflow server is running you can run the experiment
    ```shell
    python test/train.py
    ```
    and verify that the results are logged in `localhost:8080`.
  - Destroy the kubernetes resources:
    ```shell
    kubectl -n mlflow delete secret mlflow-secret
    kubectl -n mlflow delete configmap mlflow-config
    kubectl -n mlflow delete deployment mlflow-server-deployment
    kubectl -n mlflow delete service mlflow-server-service
    ```

### Kubernetes (Google cloud)

- In addition to all components that were created in the previous section we will need:
  - a static IP
  - authentication (preferably with active directory)
  - most likely, the problem with pulling images from GCR won't be present so we can avoid the creation of `gcr-io-secret`.
  
- Cluster creation:
  ```shell
  gcloud beta container --project "ai-mlflow" clusters create "cluster-1" \
    --zone "europe-west3-a" \
    --no-enable-basic-auth \
    --cluster-version "1.22.10-gke.600" \
    --release-channel "None" \
    --machine-type "e2-micro" \
    --image-type "COS_CONTAINERD" \
    --disk-type "pd-standard" \
    --disk-size "50" \
    --metadata disable-legacy-endpoints=true \
    --scopes "https://www.googleapis.com/auth/devstorage.read_only","https://www.googleapis.com/auth/logging.write","https://www.googleapis.com/auth/monitoring","https://www.googleapis.com/auth/servicecontrol","https://www.googleapis.com/auth/service.management.readonly","https://www.googleapis.com/auth/trace.append" \
    --max-pods-per-node "110" \
    --num-nodes "3" \
    --logging=SYSTEM,WORKLOAD \
    --monitoring=SYSTEM \
    --enable-ip-alias \
    --network "projects/ai-mlflow/global/networks/default" \
    --subnetwork "projects/ai-mlflow/regions/europe-west3/subnetworks/default" \
    --no-enable-intra-node-visibility \
    --default-max-pods-per-node "110" \
    --no-enable-master-authorized-networks \
    --addons HorizontalPodAutoscaling,HttpLoadBalancing,GcePersistentDiskCsiDriver \
    --enable-autoupgrade \
    --enable-autorepair \
    --max-surge-upgrade 1 \
    --max-unavailable-upgrade 0 \
    --enable-shielded-nodes \
    --node-locations "europe-west3-a"
  ```
  - Push all custom docker images to GCR:
    ```shell
    gcloud builds submit mlflow_server \
      --config mlflow_server/cloudbuild.yaml \
      --substitutions=TAG_NAME=$TAG_NAME
    ```
  - Create all cluster components except the docker-registry secret:
    ```shell
    # Change the kubernetes context
    gcloud container clusters get-credentials cluster-1 \
      --zone europe-west3-a \
      --project $PROJECT_ID

    kubectl create secret generic mlflow-secret \
      --from-file=csql-auth=$CSQL_CREDENTIALS \
      --from-file=gcs-auth=$GCS_CREDENTIALS \
      --from-literal=sql_usr=postgres \
      --from-literal=sql_pwd=$SQL_PWD \
      --from-literal=sql_db=postgres

    kubectl create -f kubernetes/configmap.yaml

    kubectl create -f kubernetes/mlflow.yaml
    ```

### Resources

[Using Google Container Registry (GCR) with Kubernetes](https://colinwilson.uk/2020/07/09/using-google-container-registry-with-kubernetes/)
