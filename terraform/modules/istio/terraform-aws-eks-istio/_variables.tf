variable "enabled" {
  type        = bool
  default     = true
  description = "Variable indicating whether Istio is enabled."
}

variable "base_enabled" {
  type        = bool
  default     = true
  description = "Variable indicating whether Istio base CRDs are enabled."
}

variable "istiod_enabled" {
  type        = bool
  default     = true
  description = "Variable indicating whether istiod is enabled."
}

variable "ingressgateway_enabled" {
  type        = bool
  default     = true
  description = "Variable indicating whether Istio ingress gateway is enabled."
}

variable "helm_chart_repo" {
  type        = string
  default     = "https://istio-release.storage.googleapis.com/charts"
  description = "Istio repository name."
}

variable "helm_chart_version" {
  type        = string
  default     = "1.25.1"
  description = "Istio helm chart version."
}

variable "create_namespace" {
  type        = bool
  default     = true
  description = "Whether to create Kubernetes namespace with name defined by `namespace`."
}

variable "namespace" {
  type        = string
  default     = "istio-system"
  description = "Kubernetes namespace for Istio"
}

variable "base_settings" {
  default     = {}
  description = "Additional settings which will be passed to the Istio Base Helm chart values."
}

variable "istiod_settings" {
  default     = {}
  description = "Additional settings which will be passed to the Istio Discovery Helm chart values."
}

variable "ingressgateway_settings" {
  default     = []
  description = "Additional settings which will be passed to the Istio Ingress Gateway Helm chart values."
}

variable "cluster_name" {
  default = ""
  type    = string
}

variable "region" {

    default="us-east-2"
    type=string
}

variable "aws_region" {

    default="us-east-2"
    type   = string
}

variable "enable_cluster_lookup" {
  type    = bool
  default = true
}
