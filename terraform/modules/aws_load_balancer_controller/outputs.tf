output "role_name" {
  value = aws_iam_role.load_balancer_controller[0].name
  description = "IAM Role name used for AWS Load Balancer Controller"
}
