provider "google" {
  project = var.project
  region  = var.region
  zone    = var.zone
}

resource "google_project_service" "iam" {
  for_each           = toset(["iam.googleapis.com", "container.googleapis.com", "cloudbuild.googleapis.com", "containerregistry.googleapis.com", "sqladmin.googleapis.com"])
  project            = var.project
  service            = each.key
  disable_on_destroy = "true"
}

module "artifacts" {
  source   = "./modules/storage"
  name     = "artifacts-4238717282752847c3d58e99"
  location = var.region
  tags = {
    Desc = "mlflow artifact storage"
  }
}

module "mlflow_backend" {
  source = "./modules/cloudsql"
  name   = "mlflow-backend"
  region = var.region
}

module "account_gcs" {
  source       = "./modules/service-account"
  name         = "gcs-access"
  display_name = "gcs-access"
  description  = "GCS access"
}

module "account_csql" {
  source       = "./modules/service-account"
  name         = "csql-access"
  display_name = "csql-access"
  description  = "CSQL access"
}

module "account_gcr" {
  source       = "./modules/service-account"
  name         = "gcr-access"
  display_name = "gcr-access"
  description  = "GCR access"
}

resource "google_storage_bucket_iam_member" "access_artifacts" {
  bucket     = module.artifacts.name
  role       = "roles/storage.admin"
  member     = "serviceAccount:${module.account_gcs.email}"
  depends_on = [module.artifacts, module.account_gcs]
}

resource "google_project_iam_member" "access_mlflow_backend" {
  project    = var.project
  role       = "roles/cloudsql.admin"
  member     = "serviceAccount:${module.account_csql.email}"
  depends_on = [module.mlflow_backend, module.account_csql]
}

resource "google_project_iam_member" "access_gcr" {
  project    = var.project
  role       = "roles/containerregistry.ServiceAgent"
  member     = "serviceAccount:${module.account_gcr.email}"
  depends_on = [module.account_gcr]
}

//resource "kubernetes_secret" "secret_mlflow" {
//  metadata {
//    name      = "mlflow-secret"
//    namespace = "mlflow"
//
//    labels = {
//      source = "terraform"
//    }
//  }
//
//  data = {
//    "csql-auth" = module.account_csql.private_key_decoded
//    "gcs-auth"  = module.account_gcs.private_key_decoded
//    "sql_usr"   = "postgres"
//    "sql_db"    = "postgres"
//  }
//}

//resource "kubernetes_secret" "gcr-io-secret" {
//  metadata {
//    name      = "gcr-io-secret"
//    namespace = "mlflow"
//
//    labels = {
//      source = "terraform"
//    }
//  }
//
//  data = {
//    "docker-server"   = "gcr.io"
//    "docker-username" = "_json_key"
//    "docker-password" = module.account_gcr.private_key_decoded
//  }
//}
