resource "aws_alb" "ALB"{
    name = "ALB"
    load_balancer_type = "application"
    security_groups = var.alb_security_group_id.id
    subnets = var.public_subnets_ids.id
}