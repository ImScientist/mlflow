output "mlflow_user_name" {
  value = google_sql_user.mlflow.name
}

output "mlflow_user_password" {
  value = google_sql_user.mlflow.password
}

output "connection_name" {
  value = google_sql_database_instance.main.connection_name
}