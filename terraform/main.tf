provider "google" {
  project = var.project
  region  = var.region
  zone    = var.zone
}

data "google_client_config" "default" {}

resource "google_project_service" "iam" {
  for_each           = toset(["iam.googleapis.com", "container.googleapis.com", "cloudbuild.googleapis.com", "containerregistry.googleapis.com", "sqladmin.googleapis.com"])
  project            = var.project
  service            = each.key
  disable_on_destroy = "true"
}

module "artifacts" {
  source   = "./modules/storage"
  name     = "artifacts-4238717282752847c3d58e44"
  location = var.region
  tags = {
    Desc = "mlflow artifact storage"
  }
}

// terraform import google_storage_bucket.ai_whatever_imported ai-whatever
resource "google_storage_bucket" "ai_whatever_imported" {
  name          = "ai-whatever"
  location      = "europe-west3"
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

resource "google_container_cluster" "primary" {
  name                     = "gcc-ai"
  location                 = var.zone  // pick region or zone
  remove_default_node_pool = true
  initial_node_count       = 1
}

resource "google_container_node_pool" "primary_preemptible_nodes" {
  name       = "primary-node-pool"
  location   = var.zone  // pick region or zone
  cluster    = google_container_cluster.primary.name
  node_count = 3

  node_config {
    preemptible  = true
    machine_type = "e2-medium"
    disk_size_gb = 20
    disk_type    = "pd-standard"

    // This service account has only read access to GCR
    service_account = module.account_gcr.email
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

  }
}

provider "kubernetes" {
  host                   = "https://${google_container_cluster.primary.endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(google_container_cluster.primary.master_auth.0.cluster_ca_certificate)
}

resource "kubernetes_namespace" "mlflow" {
  metadata {
    name   = "mlflow"

    labels = {
      mylabel = "label-mlflow-namespace"
    }

  }
}

resource "kubernetes_secret" "secret_mlflow" {
  metadata {
    name      = "mlflow-secret"
    namespace = "mlflow"

    labels = {
      source = "terraform"
    }
  }

  data = {
    "csql-auth" = module.account_csql.private_key_decoded
    "gcs-auth"  = module.account_gcs.private_key_decoded
    "sql_usr"   = "postgres"
    "sql_pwd"   = "13ce5bad0e284ab512b928ea"
    "sql_db"    = "postgres"
  }

  type = "Opaque"
  depends_on = [module.account_gcs]
}
