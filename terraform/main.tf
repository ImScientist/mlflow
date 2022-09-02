provider "google" {
  project = var.project
  region  = var.region
  zone    = var.zone
}

provider "random" {}

data "google_client_config" "default" {}

resource "google_project_service" "iam" {
  for_each           = toset(["iam.googleapis.com", "container.googleapis.com", "cloudbuild.googleapis.com", "containerregistry.googleapis.com", "sqladmin.googleapis.com"])
  project            = var.project
  service            = each.key
  disable_on_destroy = "true"
}

module "mlfow_artifacts_storage" {
  source   = "./modules/storage"
  name     = "artifacts-4238717282752847c3d58999"
  location = var.region
}

module "mlflow_backend" {
  source = "./modules/cloudsql"
  name   = "mlflow-backend"
  region = var.region
}

module "mlflow_svc_account" {
  source        = "./modules/service-account"
  name          = "mlflow-svc-account"
  bucket_roles  = [{ bucket = module.mlfow_artifacts_storage.name, role = "roles/storage.admin" }]
  project_roles = [{ project = var.project, role = "roles/cloudsql.admin" }]
}

module "container_node_svc_account" {
  source        = "./modules/service-account"
  name          = "node-pool-svc-account"
  project_roles = [{ project = var.project, role = "roles/containerregistry.ServiceAgent" }]
}

module "container_cluster" {
  source               = "./modules/container_cluster"
  zone                 = var.zone
  sevice_account_email = module.container_node_svc_account.email
}

provider "kubernetes" {
  host                   = "https://${module.container_cluster.endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(module.container_cluster.cluster_ca_certificate)
}

resource "kubernetes_namespace" "mlflow" {
  metadata {
    name = "mlflow"

    labels = {
      mylabel = "mlflow-namespace"
    }

  }

  depends_on = [module.container_cluster]
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
    "g-auth"  = module.mlflow_svc_account.private_key_decoded
    "sql_usr" = module.mlflow_backend.mlflow_user_name
    "sql_pwd" = module.mlflow_backend.mlflow_user_password
    "sql_db"  = "postgres"
  }

  type       = "Opaque"
  depends_on = [module.container_cluster, kubernetes_namespace.mlflow]
}

resource "kubernetes_config_map" "mlflow_configmap" {
  metadata {
    name      = "mlflow-config"
    namespace = "mlflow"
  }

  data = {
    artifacts_store_uri          = module.mlfow_artifacts_storage.url
    sql_instance_connection_name = module.mlflow_backend.connection_name
  }

  depends_on = [module.container_cluster, kubernetes_namespace.mlflow]
}

