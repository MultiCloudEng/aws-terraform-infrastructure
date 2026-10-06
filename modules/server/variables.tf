variable "name" {
  description = "Service name (used for resource names and the Name tag)."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,20}$", var.name))
    error_message = "name must be lowercase letters, digits and hyphens."
  }
}

variable "ami_id" {
  description = "AMI used by the launch template."
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type."
  type        = string
}

variable "security_group_id" {
  description = "Security group attached to the instances."
  type        = string
}

variable "subnet_ids" {
  description = "Subnets the Auto Scaling Group can launch instances into (multiple AZs)."
  type        = list(string)

  validation {
    condition     = length(var.subnet_ids) > 0
    error_message = "At least one subnet is required."
  }
}

variable "instance_profile_name" {
  description = "IAM instance profile (grants SSM Session Manager access)."
  type        = string
}

variable "min_size" {
  description = "Minimum number of instances."
  type        = number
  default     = 1
}

variable "max_size" {
  description = "Maximum number of instances."
  type        = number
  default     = 2

  validation {
    condition     = var.max_size <= 3
    error_message = "max_size is capped at 3 to avoid unexpected costs."
  }
}

variable "desired_capacity" {
  description = "Desired number of instances."
  type        = number
  default     = 1
}
