###############################################################################
# Environment
###############################################################################
variable "region" {
    type = string
}

variable "aws_account_id" {
    type = string
}

###############################################################################
# Cluster
###############################################################################
variable "cluster_name" {
    type = string
    default = "istio-eks-cluster"
}



variable "iam_role_name" {
  description = "The name of the IAM role"
  type        = string
  default     = "aws-load-balancer-controller"
}


variable "aws_lb_iam_role_name" {
  description = "The name of the IAM role"
  type        = string
  default     = "aws-load-balancer-controller"
}


variable "enable_cluster_lookup" {
  type    = bool
  default = true
}
#set this default to true when you create a new eks cluster everything from scratch

variable "enable_loadbalancercontrollerrole_lookup" {
  type    = bool
  default = true
  #set this default to true when you create a new eks cluster everything from scratch
}

variable "enable_ecr_auth" {
  type    = bool
  default = true
}

variable "bucket_name" {
  type    = string
  default = "570282481953-bucket-state-file-karpenter"
}