provider "google" {
  project = "ai-mlflow-02"
  region  = "europe-west3"
  zone    = "europe-west3-a"
}

module "artifacts" {
  source   = "./modules/storage"
  name     = "artifacts-4238717282752847c3d58e99"
  location = "europe-west3"
  tags = {
    Desc = "mlflow artifact storage"
  }
}

module "mlflow_backend" {
  source = "./modules/cloudsql"
  name   = "mlflow-backend"
  region = "europe-west3"
}

module "gcs_account" {
  source       = "./modules/service-account"
  name         = "gcs-access"
  display_name = "gcs-access"
  description  = "GCS access"
}

resource "google_storage_bucket_iam_member" "member" {
  bucket = module.artifacts.name
  role   = "roles/storage.admin"
  member = "serviceAccount:${module.gcs_account.email}"

  depends_on = [module.artifacts, module.gcs_account]
}
