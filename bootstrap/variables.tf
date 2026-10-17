variable "region" {
  description = "AWS region of the state bucket."
  type        = string
  default     = "eu-north-1"
}

variable "project" {
  description = "Project name used for IAM resource names and tags. Must match the main configuration."
  type        = string
  default     = "self-healing"
}

variable "state_bucket_name" {
  description = "Name of the existing S3 bucket that stores the main configuration's state."
  type        = string
  default     = "asabucket-1204"
}

variable "state_key" {
  description = "Object key of the main configuration's state file."
  type        = string
  default     = "terraform.tfstate"
}

variable "github_repository" {
  description = "GitHub repository allowed to assume the CI roles, as owner/name."
  type        = string
  default     = "MultiCloudEng/aws-terraform-infrastructure"

  validation {
    condition     = can(regex("^[A-Za-z0-9-]+/[A-Za-z0-9._-]+$", var.github_repository))
    error_message = "github_repository must be in the form owner/name."
  }
}

variable "deploy_environment" {
  description = "GitHub Environment (with required reviewers) whose jobs may assume the apply role."
  type        = string
  default     = "production"
}

variable "create_github_oidc_provider" {
  description = "Set to false if the GitHub OIDC provider already exists in this AWS account."
  type        = bool
  default     = true
}
