
variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "enable_cluster_lookup" {
  description = "Enable setup of resources"
  type        = bool
}

variable "region" {
  description = "AWS region"
  type        = string
}

