terraform {
  # 1.10+ is required for native S3 state locking (use_lockfile).
  # Works with Terraform >= 1.10 and OpenTofu >= 1.10.
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # The state bucket is created and hardened by ./bootstrap (separate state).
  # Changing these settings requires `terraform init -reconfigure`
  # (same bucket and key, so no state migration is needed).
  backend "s3" {
    bucket       = "asabucket-1204"
    key          = "terraform.tfstate"
    region       = "eu-north-1"
    encrypt      = true
    use_lockfile = true # S3-native lock file; prevents two applies at once
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = local.common_tags
  }
}
