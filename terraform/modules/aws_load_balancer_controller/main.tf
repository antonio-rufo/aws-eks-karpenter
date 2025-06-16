provider "random" {}

resource "random_id" "suffix" {
  byte_length = 4
}

resource "aws_iam_policy" "load_balancer_controller" {
  count       = var.enable_cluster_lookup ? 1 : 0
  name        = "AWSLoadBalancerControllerIAMPolicy-${random_id.suffix.hex}"
  description = "IAM policy for AWS Load Balancer Controller"
  policy      = file("${path.module}/iam-policy.json")
}

data "aws_iam_openid_connect_provider" "oidc" {
  count = var.enable_cluster_lookup ? 1 : 0
  url   = data.aws_eks_cluster.cluster[0].identity[0].oidc[0].issuer
}

resource "aws_iam_role" "load_balancer_controller" {
  count = var.enable_cluster_lookup ? 1 : 0
  name  = "AmazonEKSLoadBalancerControllerRole-${random_id.suffix.hex}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Federated = data.aws_iam_openid_connect_provider.oidc[0].arn
      },
      Action = "sts:AssumeRoleWithWebIdentity",
      Condition = {
        StringEquals = {
          "${replace(data.aws_eks_cluster.cluster[0].identity[0].oidc[0].issuer, "https://", "")}:sub" = "system:serviceaccount:kube-system:aws-load-balancer-controller"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "attach_lb_policy" {
  count      = var.enable_cluster_lookup ? 1 : 0
  policy_arn = aws_iam_policy.load_balancer_controller[0].arn
  role       = aws_iam_role.load_balancer_controller[0].name
}

resource "kubernetes_service_account" "lb_controller" {
  count = var.enable_cluster_lookup ? 1 : 0

  metadata {
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.load_balancer_controller[0].arn
    }
  }
}

resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"

  set {
    name  = "clusterName"
    value = var.cluster_name
  }

  set {
    name  = "serviceAccount.create"
    value = "false"
  }

  set {
    name  = "serviceAccount.name"
    value = kubernetes_service_account.lb_controller[0].metadata[0].name
  }

  depends_on = [kubernetes_service_account.lb_controller]
}
