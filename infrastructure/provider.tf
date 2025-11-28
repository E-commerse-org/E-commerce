terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }
  }

  backend "s3" {
    bucket  = "depi-terraform-state-file"
    key     = "terraform.tfstate"
    region  = "us-east-1"
    encrypt = true
  }
}

provider "aws" {
  region = var.region
}

data "aws_eks_cluster_auth" "auth" {
  for_each = module.computes
  name     = each.value.cluster_info.name
}
provider "kubernetes" {
  alias                  = "cell1"
  host                   = module.computes["cell1"].cluster_info.endpoint
  cluster_ca_certificate = base64decode(module.computes["cell1"].cluster_info.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.auth["cell1"].token
}

provider "kubernetes" {
  alias                  = "cell2"
  host                   = module.computes["cell2"].cluster_info.endpoint
  cluster_ca_certificate = base64decode(module.computes["cell2"].cluster_info.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.auth["cell2"].token
}

provider "kubernetes" {
  alias                  = "cell3"
  host                   = module.computes["cell3"].cluster_info.endpoint
  cluster_ca_certificate = base64decode(module.computes["cell3"].cluster_info.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.auth["cell3"].token
}

provider "helm" {
  alias = "cell1"

  kubernetes = {
    host                   = module.computes["cell1"].cluster_info.endpoint
    cluster_ca_certificate = base64decode(module.computes["cell1"].cluster_info.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.auth["cell1"].token
  }
}

provider "helm" {
  alias = "cell2"

  kubernetes = {
    host                   = module.computes["cell2"].cluster_info.endpoint
    cluster_ca_certificate = base64decode(module.computes["cell2"].cluster_info.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.auth["cell2"].token
  }
}

provider "helm" {
  alias = "cell3"

  kubernetes = {
    host                   = module.computes["cell3"].cluster_info.endpoint
    cluster_ca_certificate = base64decode(module.computes["cell3"].cluster_info.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.auth["cell3"].token
  }
}

