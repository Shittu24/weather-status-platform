variable "admin_cidr" {
  description = "Operator public IPv4 /32 for the EKS API, supplied outside Git."
  type        = string
  validation {
    condition     = can(cidrhost(var.admin_cidr, 0)) && endswith(var.admin_cidr, "/32")
    error_message = "Use one IPv4 /32, never a publicly open API range."
  }
}
variable "admin_principal_arn" {
  description = "Stable IAM principal ARN, not an STS session ARN."
  type        = string
}
locals {
  name    = "weather-dev"
  version = "1.36"
  zones   = ["us-east-1a", "us-east-1b"]
}
