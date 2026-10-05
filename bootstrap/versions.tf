terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # Bootstrap uses LOCAL state on purpose: it creates the bucket that the main
  # configuration stores its state in, so it cannot store its own state there
  # before the bucket exists. Never commit terraform.tfstate (see .gitignore).
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project   = var.project
      ManagedBy = "terraform"
      Component = "bootstrap"
    }
  }
}
