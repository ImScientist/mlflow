output "id" {
  value = google_service_account.svc_account.id
}

output "email" {
  value = google_service_account.svc_account.email
}

output "name" {
  value = google_service_account.svc_account.name
}

output "private_key_decoded" {
  value = base64decode(google_service_account_key.svc_account_key.private_key)
}

output "private_key" {
  value = google_service_account_key.svc_account_key.private_key
}
