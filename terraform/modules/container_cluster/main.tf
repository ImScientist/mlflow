resource "google_container_cluster" "primary" {
  name                     = "gcc-mlflow"
  location                 = var.zone // pick region or zone
  remove_default_node_pool = true
  initial_node_count       = 1
}

resource "google_container_node_pool" "primary_preemptible_nodes" {
  name       = "primary-node-pool"
  location   = var.zone // pick region or zone
  cluster    = google_container_cluster.primary.name
  node_count = 3

  node_config {
    preemptible  = true
    machine_type = "e2-medium"
    disk_size_gb = 20
    disk_type    = "pd-standard"

    // This service account has only read access to GCR
    service_account = var.sevice_account_email
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

  }
}
