resource "google_sql_database_instance" "main" {
  name             = var.name
  database_version = "POSTGRES_9_6"
  region           = var.region

  settings {
    tier              = "db-f1-micro"
    activation_policy = "ALWAYS"
    disk_autoresize   = "false"
    disk_size         = 10
  }
}

resource "random_password" "password" {
  length           = 32
  special          = false
}

resource "google_sql_user" "mlflow" {
  name     = "mlflow"
  instance = google_sql_database_instance.main.name
  password = random_password.password.result
}
