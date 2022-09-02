#!/usr/bin/env sh

echo """
######################################################################
# Create the following resources in Google cloud:                    #
#  - Bucket in cloud storage that will be used as artifact storage   #
#  - PostgreSQL DB in cloud SQL that will be used as a backend db    #
#  - Service account (and json-key) with access to GCS and cloud SQL #
#  - Container registry with the mlflow image in `mlflow_server`     #
######################################################################
"""
PROJECT_ID=$(gcloud config list --format='value(core.project)')
PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format='value(projectNumber)')



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
gcloud sql instances create $SQL_INSTANCE_NAME \
  --database-version=POSTGRES_9_6 \
  --tier db-f1-micro \
  --storage-size=10 \
  --region=europe-west3 \
  --root-password=$SQL_PWD



echo """
Create a service account with GCS access
Create a service account with cloud SQL access
Create a key that will be stored locally in ./mlflow_credentials ...
"""
acc_name=mlflow-svc-account
#acc_name=gcs-access

gcloud iam service-accounts create ${acc_name}

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member "serviceAccount:${acc_name}@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role "roles/storage.admin"

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member "serviceAccount:${acc_name}@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role "roles/cloudsql.admin"

gcloud iam service-accounts keys create $GCS_CREDENTIALS \
      --iam-account=${acc_name}@${PROJECT_ID}.iam.gserviceaccount.com



echo """
Create a service account with cloud container registry access
Create a key that will be stored locally in ./mlflow_credentials ...
"""
acc_name=gcr-access

gcloud iam service-accounts create ${acc_name}

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member "serviceAccount:${acc_name}@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role "roles/containerregistry.ServiceAgent"

gcloud iam service-accounts keys create $GCR_CREDENTIALS \
  --iam-account=${acc_name}@${PROJECT_ID}.iam.gserviceaccount.com



echo """
Add the custom mlflow image in `mlflow_server` to the container registry ...
"""
gcloud builds submit mlflow_server \
    --config mlflow_server/cloudbuild.yaml \
    --substitutions=TAG_NAME=$TAG_NAME
