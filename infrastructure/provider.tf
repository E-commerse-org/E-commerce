terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket  = "depi-terraform-state-file"
    key     = "terraform.tfstate"
    region  = "us-east-1"
    encrypt = true
    profile = "depi"
  }
}

provider "aws" {
  region  = var.region
  profile = "depi"
}
