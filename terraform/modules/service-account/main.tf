resource "google_service_account" "svc_account" {
  account_id   = var.name
  display_name = var.display_name
  description  = var.description
}

resource "google_service_account_key" "svc_account_key" {
  service_account_id = google_service_account.svc_account.name
}
