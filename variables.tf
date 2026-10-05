variable "region" {
  description = "AWS region for all resources."
  type        = string
  default     = "eu-north-1"

  validation {
    condition     = can(regex("^[a-z]{2}(-[a-z]+)+-\\d$", var.region))
    error_message = "region must look like an AWS region, e.g. eu-north-1."
  }
}

variable "project" {
  description = "Short project name, used in resource names and tags."
  type        = string
  default     = "self-healing"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,20}$", var.project))
    error_message = "project must be 3-21 chars: lowercase letters, digits and hyphens, starting with a letter."
  }
}

variable "environment" {
  description = "Environment name used in tags."
  type        = string
  default     = "demo"

  validation {
    condition     = contains(["demo", "dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: demo, dev, staging, prod."
  }
}

variable "instance_type" {
  description = "EC2 instance type. Restricted to small burstable types to keep costs low."
  type        = string
  default     = "t3.micro"

  validation {
    condition     = can(regex("^t[34]g?\\.(nano|micro|small)$", var.instance_type))
    error_message = "instance_type must be a small burstable type (t3/t3a-style nano, micro or small)."
  }
}

variable "ami_id" {
  description = "Optional AMI override. Leave null to use the latest Amazon Linux 2023 AMI (includes the SSM Agent)."
  type        = string
  default     = null

  validation {
    condition     = var.ami_id == null || can(regex("^ami-[0-9a-f]{8,17}$", var.ami_id))
    error_message = "ami_id must be null or a valid AMI ID (ami-...)."
  }
}
