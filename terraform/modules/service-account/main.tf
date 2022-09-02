resource "google_service_account" "svc_account" {
  account_id   = var.name
  display_name = var.display_name != "" ? var.display_name : var.name
  description  = var.description
}

resource "google_service_account_key" "svc_account_key" {
  service_account_id = google_service_account.svc_account.name
}

resource "google_project_iam_member" "svc_account_role" {
  for_each   = {for i, v in var.project_roles:  i => v}

  project    = each.value.project
  role       = each.value.role
  member     = "serviceAccount:${google_service_account.svc_account.email}"
}

resource "google_storage_bucket_iam_member" "svc_account_storage_access" {
  for_each   = {for i, v in var.bucket_roles: i => v}

  bucket     = each.value.bucket
  role       = each.value.role
  member     = "serviceAccount:${google_service_account.svc_account.email}"
}