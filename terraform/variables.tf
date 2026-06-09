variable "aws_region" {
  type        = string
  description = "The AWS region to deploy secure resources into"
  default     = "us-east-1"
}

variable "environment" {
  type        = string
  description = "Deployment environment tracking tag"
  default     = "production"
}