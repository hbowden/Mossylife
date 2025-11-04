variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "qf-review"
}

variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-west-2"
}

variable "aws_profile" {
  description = "AWS CLI profile to use (for SSO or named profiles)"
  type        = string
  default     = "personal"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"
}

variable "domain_name" {
  description = "Domain name for the website (leave empty to use CloudFront URL only)"
  type        = string
  default     = "mossylife.com"
}
