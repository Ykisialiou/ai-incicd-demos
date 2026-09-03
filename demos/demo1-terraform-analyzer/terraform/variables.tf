variable "environment" {
  type        = string
  default     = "production"
  description = "Target deployment environment"
}

variable "db_allocated_storage" {
  type        = number
  default     = 20
  description = "Allocated storage in GB"
}
