
output "alb_security_group_id" {
  description = "Load Balancer SG"
  value = aws_security_group.SG_ALB.id
}

output "instance_security_group_id" {
  description = "Instance SG"
  value = aws_security_group.SG_INSTANCE.id
}