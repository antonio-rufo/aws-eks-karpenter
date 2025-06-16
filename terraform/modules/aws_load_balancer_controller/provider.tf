
# Fetch EKS Cluster Data
data "aws_eks_cluster" "cluster" {
  count = var.enable_cluster_lookup ? 1 : 0
  name = var.cluster_name
}

data "aws_eks_cluster_auth" "cluster" {
  count = var.enable_cluster_lookup ? 1 : 0
  name = var.cluster_name
}


provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster[0].endpoint
  token                  = data.aws_eks_cluster_auth.cluster[0].token
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster[0].certificate_authority[0].data)
}

provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.cluster[0].endpoint
    token                  = data.aws_eks_cluster_auth.cluster[0].token
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster[0].certificate_authority[0].data)
  }
}

provider "kubectl" {
  apply_retry_count = 5

  host                   = data.aws_eks_cluster.cluster[0].endpoint
  token                  = data.aws_eks_cluster_auth.cluster[0].token
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster[0].certificate_authority[0].data)
}

terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.24"
    }

    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.13"
    }

    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.14"
    }
  }
}
