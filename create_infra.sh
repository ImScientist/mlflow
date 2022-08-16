#!/usr/bin/env sh

echo """
####################################################################
# Create the following resources in Google cloud:                  #
#  - Bucket in cloud storage that will be used as artifact storage #
#  - PostgreSQL DB in cloud SQL that will be used as a backend db  #
#  - Service account (and json-key) with access to GCS             #
#  - Service account (and json-key) with access to cloud SQL       #
#  - Container registry with the mlflow image in `mlflow_server`   #
####################################################################
"""

INSTANCE_NAME=mlflow-backend
REGION=europe-west3
TAG_NAME=1.0.0


PROJECT_ID=$(gcloud config list --format='value(core.project)')
PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format='value(projectNumber)')
RAND_NUMBER=$(openssl rand -hex 12)
BUCKET_NAME="artifacts-${RAND_NUMBER}"
SQL_PWD=$(openssl rand -hex 12)



echo """
Enable relevant services ...
"""
gcloud services enable \
  container.googleapis.com \
  cloudbuild.googleapis.com \
  containerregistry.googleapis.com \
  sqladmin.googleapis.com \
  iam.googleapis.com



echo """
Create bucket ...
"""
gsutil mb gs://$BUCKET_NAME



echo """
Create backend DB ...
"""
gcloud sql instances create $INSTANCE_NAME \
  --database-version=POSTGRES_9_6 \
  --tier db-f1-micro \
  --storage-size=10 \
  --region=europe-west3 \
  --root-password=$SQL_PWD



echo """
Create a service account with GCS access
Create a key that will be stored in mlflow_credentials ...
"""
acc_name=gcs-access
GCS_CREDENTIALS=".mlflow_credentials/${acc_name}.json"

gcloud iam service-accounts create ${acc_name}

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member "serviceAccount:${acc_name}@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role "roles/storage.admin"

gcloud iam service-accounts keys create $GCS_CREDENTIALS \
      --iam-account=${acc_name}@${PROJECT_ID}.iam.gserviceaccount.com



echo """
Create a service account with cloud SQL access
Create a key that will be stored in mlflow_credentials ...
"""
acc_name=csql-access
CSQL_CREDENTIALS="$(echo ~)/.mlflow_credentials/${acc_name}.json"

gcloud iam service-accounts create ${acc_name}

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member "serviceAccount:${acc_name}@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role "roles/cloudsql.admin"

gcloud iam service-accounts keys create $CSQL_CREDENTIALS \
  --iam-account=${acc_name}@${PROJECT_ID}.iam.gserviceaccount.com



echo """
Create a service account with cloud container registry access
Create a key that will be stored in mlflow_credentials ...
"""
acc_name=gcr-access
GCR_CREDENTIALS="$(echo ~)/.mlflow_credentials/${acc_name}.json"

gcloud iam service-accounts create ${acc_name}

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member "serviceAccount:${acc_name}@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role "roles/containerregistry.ServiceAgent"

#gcloud projects add-iam-policy-binding $PROJECT_ID \
#  --member "serviceAccount:${acc_name}@${PROJECT_ID}.iam.gserviceaccount.com" \
#  --role "roles/storage.admin"

gcloud iam service-accounts keys create $GCR_CREDENTIALS \
  --iam-account=${acc_name}@${PROJECT_ID}.iam.gserviceaccount.com



echo """
Add the custom mlflow image in `mlflow_server` to the container registry ...
"""
gcloud builds submit mlflow_server \
    --config mlflow_server/cloudbuild.yaml \
    --substitutions=TAG_NAME=$TAG_NAME
