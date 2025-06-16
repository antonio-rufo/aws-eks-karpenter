        

resource "kubernetes_namespace" "istio" {
   metadata {
    name = var.namespace
    labels = {
      "istio-injection" = "enabled"
    }
  }
}



resource "helm_release" "istio_base" {
  depends_on = [kubernetes_namespace.istio]
  count      = var.enabled && var.base_enabled ? 1 : 0
  name       = "istio-base"
  repository = var.helm_chart_repo
  chart      = "base"
  version    = var.helm_chart_version
  namespace  = var.namespace

  values = [
    yamlencode(var.base_settings)
  ]

}

resource "helm_release" "istiod" {
  depends_on = [
    helm_release.istio_base
  ]
  count      = var.enabled && var.istiod_enabled ? 1 : 0
  name       = "istio-istiod"
  repository = var.helm_chart_repo
  chart      = "istiod"
  version    = var.helm_chart_version
  namespace  = var.namespace

  values = [
    yamlencode(merge(
      var.istiod_settings,
      {
        tolerations = [
          {
            key      = "CriticalAddonsOnly"
            operator = "Exists"
          }
        ]
      }
    ))
  ]

   timeout = 600 # Increase timeout to 10 minutes

}



resource "helm_release" "istio_ingressgateway" {
  depends_on = [
    helm_release.istiod
  ]
  count      = var.enabled && var.ingressgateway_enabled ? length(var.ingressgateway_settings) : 0
  name       = var.ingressgateway_settings[count.index].name
  repository = var.helm_chart_repo
  chart      = "gateway"
  version    = var.helm_chart_version
  namespace  = var.namespace

  set {
    name  = "service.type"
    value = "NodePort"
  }

  set {
    name  = "securityContext.runAsUser"
    value = 1337
  }

  set {
    name  = "securityContext.runAsGroup"
    value = 1337
  }

  set {
    name  = "securityContext.runAsNonRoot"
    value = true
  }
}





resource "null_resource" "istio_addons" {
  provisioner "local-exec" {
    command = <<EOT
#!/bin/bash
set -e

# Enable injection and ambient mode
kubectl label namespace default istio-injection=enabled --overwrite
kubectl label namespace default istio.io/dataplane-mode=ambient --overwrite

# Apply Istio addons
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.25/samples/addons/prometheus.yaml
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.25/samples/addons/kiali.yaml
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.25/samples/addons/jaeger.yaml

# Install Argo Rollouts
kubectl create namespace argo-rollouts --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argo-rollouts -f https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml    

# Create tracing config YAML
cat > ./tracing.yaml <<EOF
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
spec:
  meshConfig:
    enableTracing: true
    defaultConfig:
      tracing: {}
    extensionProviders:
    - name: jaeger
      opentelemetry:
        port: 4317
        service: jaeger-collector.istio-system.svc.cluster.local
EOF

# Apply tracing config
~/istio-1.25.1/bin/istioctl install -f ./tracing.yaml --skip-confirmation

# Apply telemetry config
kubectl apply -f - <<EOF
apiVersion: telemetry.istio.io/v1
kind: Telemetry
metadata:
  name: mesh-default
  namespace: istio-system
spec:
  tracing:
  - providers:
    - name: jaeger
EOF

EOT
  }

  triggers = {
    always_run = timestamp()
  }
}



###############################################################################
# BOOKINFO: DETAILS RESOURCES
###############################################################################

resource "kubernetes_manifest" "bookinfo_details_service" {
  depends_on = [helm_release.istio_base]
  manifest = {
    apiVersion = "v1"
    kind       = "Service"
    metadata = {
      name   = "details"
      namespace = "default"
      labels = {
        app     = "details"
        service = "details"
      }
    }
    spec = {
      ports = [
        {
          port = 9080
          name = "http"
        }
      ]
      selector = {
        app = "details"
      }
    }
  }
}

resource "kubernetes_manifest" "bookinfo_details_serviceaccount" {
  depends_on = [helm_release.istio_base]
  manifest = {
    apiVersion = "v1"
    kind       = "ServiceAccount"
    metadata = {
      name   = "bookinfo-details"
      namespace = "default"
      labels = {
        account = "details"
      }
    }
  }
}

resource "kubernetes_manifest" "bookinfo_details_deployment" {
  depends_on = [helm_release.istio_base] 
  manifest = {
    apiVersion = "apps/v1"
    kind       = "Deployment"
    metadata = {
      name   = "details-v1"
      namespace = "default"
      labels = {
        app     = "details"
        version = "v1"
      }
    }
    spec = {
      replicas = 1
      selector = {
        matchLabels = {
          app     = "details"
          version = "v1"
        }
      }
      template = {
        metadata = {
          labels = {
            app     = "details"
            version = "v1"
          }
        }
        spec = {
          serviceAccountName = "bookinfo-details"
          containers = [
            {
              name            = "details"
              image           = "docker.io/istio/examples-bookinfo-details-v1:1.20.2"
              imagePullPolicy = "IfNotPresent"
              ports           = [
                { containerPort = 9080 }
              ]
            }
          ]
        }
      }
    }
  }
}

###############################################################################
# BOOKINFO: RATINGS RESOURCES
###############################################################################

resource "kubernetes_manifest" "bookinfo_ratings_service" {
  depends_on = [helm_release.istio_base]
  manifest = {
    apiVersion = "v1"
    kind       = "Service"
    metadata = {
      name   = "ratings"
      namespace = "default"
      labels = {
        app     = "ratings"
        service = "ratings"
      }
    }
    spec = {
      ports = [
        {
          port = 9080
          name = "http"
        }
      ]
      selector = {
        app = "ratings"
      }
    }
  }
}

resource "kubernetes_manifest" "bookinfo_ratings_serviceaccount" {
  depends_on = [helm_release.istio_base]
  manifest = {
    apiVersion = "v1"
    kind       = "ServiceAccount"
    metadata = {
      name   = "bookinfo-ratings"
      namespace = "default"
      labels = {
        account = "ratings"
      }
    }
  }
}

resource "kubernetes_manifest" "bookinfo_ratings_deployment" {
  depends_on = [helm_release.istio_base]
  manifest = {
    apiVersion = "apps/v1"
    kind       = "Deployment"
    metadata = {
      name   = "ratings-v1"
      namespace = "default"
      labels = {
        app     = "ratings"
        version = "v1"
      }
    }
    spec = {
      replicas = 1
      selector = {
        matchLabels = {
          app     = "ratings"
          version = "v1"
        }
      }
      template = {
        metadata = {
          labels = {
            app     = "ratings"
            version = "v1"
          }
        }
        spec = {
          serviceAccountName = "bookinfo-ratings"
          containers = [
            {
              name            = "ratings"
              image           = "docker.io/istio/examples-bookinfo-ratings-v1:1.20.2"
              imagePullPolicy = "IfNotPresent"
              ports           = [
                { containerPort = 9080 }
              ]
            }
          ]
        }
      }
    }
  }
}

###############################################################################
# BOOKINFO: REVIEWS RESOURCES
###############################################################################

resource "kubernetes_manifest" "bookinfo_reviews_service" {
  depends_on = [helm_release.istio_base]
  manifest = {
    apiVersion = "v1"
    kind       = "Service"
    metadata = {
      name   = "reviews"
      namespace = "default"
      labels = {
        app     = "reviews"
        service = "reviews"
      }
    }
    spec = {
      ports = [
        {
          port = 9080
          name = "http"
        }
      ]
      selector = {
        app = "reviews"
      }
    }
  }
}

resource "kubernetes_manifest" "bookinfo_reviews_serviceaccount" {
  depends_on = [helm_release.istio_base]
  manifest = {
    apiVersion = "v1"
    kind       = "ServiceAccount"
    metadata = {
      name   = "bookinfo-reviews"
      namespace = "default"
      labels = {
        account = "reviews"
      }
    }
  }
}

resource "kubernetes_manifest" "bookinfo_reviews_deployment_v1" {
  depends_on = [helm_release.istio_base]
  manifest = {
    apiVersion = "apps/v1"
    kind       = "Deployment"
    metadata = {
      name   = "reviews-v1"
      namespace = "default"
      labels = {
        app     = "reviews"
        version = "v1"
      }
    }
    spec = {
      replicas = 1
      selector = {
        matchLabels = {
          app     = "reviews"
          version = "v1"
        }
      }
      template = {
        metadata = {
          labels = {
            app     = "reviews"
            version = "v1"
          }
        }
        spec = {
          serviceAccountName = "bookinfo-reviews"
          containers = [
            {
              name            = "reviews"
              image           = "docker.io/istio/examples-bookinfo-reviews-v1:1.20.2"
              imagePullPolicy = "IfNotPresent"
              env = [
                { name = "LOG_DIR", value = "/tmp/logs" }
              ]
              ports = [
                { containerPort = 9080 }
              ]
              volumeMounts = [
                { name = "tmp", mountPath = "/tmp" },
                { name = "wlp-output", mountPath = "/opt/ibm/wlp/output" }
              ]
            }
          ]
          volumes = [
            { name = "wlp-output", emptyDir = {} },
            { name = "tmp", emptyDir = {} }
          ]
        }
      }
    }
  }
}

resource "kubernetes_manifest" "bookinfo_reviews_deployment_v2" {
  depends_on = [helm_release.istio_base]
  manifest = {
    apiVersion = "apps/v1"
    kind       = "Deployment"
    metadata = {
      name   = "reviews-v2"
      namespace = "default"
      labels = {
        app     = "reviews"
        version = "v2"
      }
    }
    spec = {
      replicas = 1
      selector = {
        matchLabels = {
          app     = "reviews"
          version = "v2"
        }
      }
      template = {
        metadata = {
          labels = {
            app     = "reviews"
            version = "v2"
          }
        }
        spec = {
          serviceAccountName = "bookinfo-reviews"
          containers = [
            {
              name            = "reviews"
              image           = "docker.io/istio/examples-bookinfo-reviews-v2:1.20.2"
              imagePullPolicy = "IfNotPresent"
              env = [
                { name = "LOG_DIR", value = "/tmp/logs" }
              ]
              ports = [
                { containerPort = 9080 }
              ]
              volumeMounts = [
                { name = "tmp", mountPath = "/tmp" },
                { name = "wlp-output", mountPath = "/opt/ibm/wlp/output" }
              ]
            }
          ]
          volumes = [
            { name = "wlp-output", emptyDir = {} },
            { name = "tmp", emptyDir = {} }
          ]
        }
      }
    }
  }
}

resource "kubernetes_manifest" "bookinfo_reviews_deployment_v3" {
  depends_on = [helm_release.istio_base]
  manifest = {
    apiVersion = "apps/v1"
    kind       = "Deployment"
    metadata = {
      name   = "reviews-v3"
      namespace = "default"
      labels = {
        app     = "reviews"
        version = "v3"
      }
    }
    spec = {
      replicas = 1
      selector = {
        matchLabels = {
          app     = "reviews"
          version = "v3"
        }
      }
      template = {
        metadata = {
          labels = {
            app     = "reviews"
            version = "v3"
          }
        }
        spec = {
          serviceAccountName = "bookinfo-reviews"
          containers = [
            {
              name            = "reviews"
              image           = "docker.io/istio/examples-bookinfo-reviews-v3:1.20.2"
              imagePullPolicy = "IfNotPresent"
              env = [
                { name = "LOG_DIR", value = "/tmp/logs" }
              ]
              ports = [
                { containerPort = 9080 }
              ]
              volumeMounts = [
                { name = "tmp", mountPath = "/tmp" },
                { name = "wlp-output", mountPath = "/opt/ibm/wlp/output" }
              ]
            }
          ]
          volumes = [
            { name = "wlp-output", emptyDir = {} },
            { name = "tmp", emptyDir = {} }
          ]
        }
      }
    }
  }
}

###############################################################################
# BOOKINFO: PRODUCTPAGE RESOURCES
###############################################################################

resource "kubernetes_manifest" "bookinfo_productpage_service" {
  depends_on = [helm_release.istio_base]
  manifest = {
    apiVersion = "v1"
    kind       = "Service"
    metadata = {
      name   = "productpage"
      namespace = "default"
      labels = {
        app     = "productpage"
        service = "productpage"
      }
    }
    spec = {
      ports = [
        {
          port = 9080
          name = "http"
        }
      ]
      selector = {
        app = "productpage"
      }
    }
  }
}

resource "kubernetes_manifest" "bookinfo_productpage_serviceaccount" {
  depends_on = [helm_release.istio_base]
  manifest = {
    apiVersion = "v1"
    kind       = "ServiceAccount"
    metadata = {
      name   = "bookinfo-productpage"
      namespace = "default"
      labels = {
        account = "productpage"
      }
    }
  }
}

resource "kubernetes_manifest" "bookinfo_productpage_deployment" {
  depends_on = [helm_release.istio_base]
  manifest = {
    apiVersion = "apps/v1"
    kind       = "Deployment"
    metadata = {
      name   = "productpage-v1"
      namespace = "default"
      labels = {
        app     = "productpage"
        version = "v1"
      }
    }
    spec = {
      replicas = 1
      selector = {
        matchLabels = {
          app     = "productpage"
          version = "v1"
        }
      }
      template = {
        metadata = {
          annotations = {
            "prometheus.io/scrape" = "true"
            "prometheus.io/port"   = "9080"
            "prometheus.io/path"   = "/metrics"
          }
          labels = {
            app     = "productpage"
            version = "v1"
          }
        }
        spec = {
          serviceAccountName = "bookinfo-productpage"
          containers = [
            {
              name            = "productpage"
              image           = "docker.io/istio/examples-bookinfo-productpage-v1:1.20.2"
              imagePullPolicy = "IfNotPresent"
              ports           = [
                { containerPort = 9080 }
              ]
              volumeMounts = [
                { name = "tmp", mountPath = "/tmp" }
              ]
            }
          ]
          volumes = [
            { name = "tmp", emptyDir = {} }
          ]
        }
      }
    }
  }
}

###############################################################################
# ISTIO RESOURCES (GATEWAY, VIRTUALSERVICES, DESTINATIONRULES)
###############################################################################

# Gateway to expose productpage
resource "kubernetes_manifest" "bookinfo_gateway" {
  depends_on = [helm_release.istio_base]
  manifest = {
    apiVersion = "networking.istio.io/v1beta1"
    kind       = "Gateway"
    metadata = {
      name      = "bookinfo-gateway"
      namespace = "default"
    }
    spec = {
      selector = {
        app   = "istio-ingressgateway"
        istio = "ingressgateway"
      }
      servers = [
        {
          port = {
            number   = 80
            name     = "http"
            protocol = "HTTP"
          }
          hosts = ["*"]
        }
      ]
    }
  }
}

# VirtualService for productpage (entrypoint via Gateway)
resource "kubernetes_manifest" "bookinfo_virtualservice_productpage" {
  depends_on = [helm_release.istio_base]
  manifest = {
    apiVersion = "networking.istio.io/v1beta1"
    kind       = "VirtualService"
    metadata = {
      name      = "productpage"
      namespace = "default"
    }
    spec = {
      hosts    = ["*"]
      gateways = ["bookinfo-gateway"]
      http     = [
        {
          route = [
            {
              destination = {
                host = "productpage"
                port = {
                  number = 9080
                }
              }
            }
          ]
        }
      ]
    }
  }
   field_manager {
    name            = "terraform"
    force_conflicts = true
  }
}

# VirtualService for details (route all traffic to v1)
resource "kubernetes_manifest" "bookinfo_virtualservice_details" {
  depends_on = [helm_release.istio_base]
  manifest = {
    apiVersion = "networking.istio.io/v1beta1"
    kind       = "VirtualService"
    metadata = {
      name      = "details"
      namespace = "default"
    }
    spec = {
      hosts = ["details"]
      http  = [
        {
          route = [
            {
              destination = {
                host   = "details"
                subset = "v1"
                port = { number = 9080 }
              }
            }
          ]
        }
      ]
    }
  }
   field_manager {
    name            = "terraform"
    force_conflicts = true
  }
}

# VirtualService for ratings (split traffic among v1, v2, v3)
resource "kubernetes_manifest" "bookinfo_virtualservice_ratings" {
  depends_on = [helm_release.istio_base]
  manifest = {
    apiVersion = "networking.istio.io/v1beta1"
    kind       = "VirtualService"
    metadata = {
      name      = "ratings"
      namespace = "default"
    }
    spec = {
      hosts = ["ratings"]
      http  = [
        {
          route = [
            {
              destination = {
                host   = "ratings"
                subset = "v1"
                port = { number = 9080 }
              }
              weight = 100
            }
          ]
        }
      ]
    }
  }

   field_manager {
    name            = "terraform"
    force_conflicts = true
  }
}

# VirtualService for reviews (split traffic between v1 and v2)
resource "kubernetes_manifest" "bookinfo_virtualservice_reviews" {
  depends_on = [helm_release.istio_base]
  manifest = {
    apiVersion = "networking.istio.io/v1beta1"
    kind       = "VirtualService"
    metadata = {
      name      = "reviews"
      namespace = "default"
    }
    spec = {
      hosts = ["reviews"]
      http  = [
        {
          route = [
            {
              destination = {
                host   = "reviews"
                subset = "v1"
                port = { number = 9080 }
              }
              weight = 40
            },
            {
              destination = {
                host   = "reviews"
                subset = "v2"
                port = { number = 9080 }
              }
              weight = 60
            }
          ]
        }
      ]
    }
  }
   field_manager {
    name            = "terraform"
    force_conflicts = true
  }
}

# DestinationRule for details
resource "kubernetes_manifest" "bookinfo_destinationrule_details" {
  depends_on = [helm_release.istio_base]
  manifest = {
    apiVersion = "networking.istio.io/v1beta1"
    kind       = "DestinationRule"
    metadata = {
      name      = "details"
      namespace = "default"
    }
    spec = {
      host    = "details"
      subsets = [
        {
          name   = "v1"
          labels = { version = "v1" }
        }
      ]
    }
  }
}

# DestinationRule for ratings
resource "kubernetes_manifest" "bookinfo_destinationrule_ratings" {
  depends_on = [helm_release.istio_base]
  manifest = {
    apiVersion = "networking.istio.io/v1beta1"
    kind       = "DestinationRule"
    metadata = {
      name      = "ratings"
      namespace = "default"
    }
    spec = {
      host    = "ratings"
      subsets = [
        {
          name   = "v1"
          labels = { version = "v1" }
        }
      ]
    }
  }
}

# DestinationRule for reviews
resource "kubernetes_manifest" "bookinfo_destinationrule_reviews" {
  depends_on = [helm_release.istio_base]
  manifest = {
    apiVersion = "networking.istio.io/v1beta1"
    kind       = "DestinationRule"
    metadata = {
      name      = "reviews"
      namespace = "default"
    }
    spec = {
      host    = "reviews"
      subsets = [
        {
          name   = "v1"
          labels = { version = "v1" }
        },
        {
          name   = "v2"
          labels = { version = "v2" }
        }
      ]
    }
  }
}

resource "kubernetes_ingress_v1" "istio_ingress_alb" {
  metadata {
    name      = "istio-ingress-alb"
    namespace = "istio-system"
    annotations = {
      "kubernetes.io/ingress.class"                = "alb"
      "alb.ingress.kubernetes.io/scheme"           = "internet-facing"
      "alb.ingress.kubernetes.io/target-type"      = "instance"
      "alb.ingress.kubernetes.io/listen-ports"     = "[{\"HTTP\":80}]"
    }
  }

  spec {
    rule {
      http {
        path {
          path     = "/*"
          path_type = "ImplementationSpecific"

          backend {
            service {
              name = "istio-ingressgateway"
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }
}

output "istio_ingress_alb_status" {
  description = "Confirmation message for Istio Ingress ALB deployment"
  value       = "Ingress 'istio-ingress-alb' has been deployed in the 'istio-system' namespace."
}



output "istio_ingress_alb_hostname_yes_or_no" {
  description = "ALB hostname for Istio Ingress"
  value = (
    length(kubernetes_ingress_v1.istio_ingress_alb.status[0].load_balancer[0].ingress) > 0 ?
    kubernetes_ingress_v1.istio_ingress_alb.status[0].load_balancer[0].ingress[0].hostname :
    "ALB hostname not yet available"
  )
}



#CANRY RELEASE DEPLOYMENT IS DONE SUCCESSFULLY

output "canary_release_status" {
  value = "CANARY RELEASE DEPLOYMENT IS DONE SUCCESSFULLY"
}


