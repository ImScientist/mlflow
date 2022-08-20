variable "name" {
  description = "A unique bucket name"
}

variable "location" {
  description = "Storage location"
}

variable "tags" {
  type        = map(string)
  description = "Any tags"
  default     = {}
}
