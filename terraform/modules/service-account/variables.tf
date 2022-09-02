variable "name" {
  description = "A unique service account name"
}

variable "display_name" {
  description = "Service account name"
  default = ""
}

variable "description" {
  description = "Service account description"
  default = ""
}

variable "project_roles" {
  type = list(object({
    project  = string
    role     = string
  }))
  default = []
}

variable "bucket_roles" {
  type = list(object({
    bucket = string
    role   = string
  }))
  default = []
}