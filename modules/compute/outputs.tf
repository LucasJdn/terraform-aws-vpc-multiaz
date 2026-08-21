output "alb_dns_name" {
  description = "Public DNS for ALB"
  value       = aws_alb.ALB.dns_name
}