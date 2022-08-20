resource "google_storage_bucket" "storage" {
  name          = var.name
  location      = var.location
  storage_class = "REGIONAL"
  force_destroy = true

  uniform_bucket_level_access = true
}
