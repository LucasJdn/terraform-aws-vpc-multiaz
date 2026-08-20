resource "aws_lb_target_group" "TG_ALB"{
    name = "tg-alb"
    port = 80
    protocol = "HTTP"
    vpc_id = var.vpc_id


    health_check {
        path                = "/"
        healthy_threshold   = 2
        unhealthy_threshold = 2
        interval            = 30
        timeout             = 5
  }
}

resource "aws_alb" "ALB"{
    name = "ALB"
    load_balancer_type = "application"
    internal = false
    security_groups = [var.alb_security_group_id]
    subnets = var.public_subnets_ids

    tags = {
        Name = "Application Load Balancer"
    }
}

resource "aws_lb_listener" "Listener_ALB"{
    load_balancer_arn = aws_alb.ALB.arn
    port = 80
    protocol = "HTTP"

    default_action {
      type = "forward"
      target_group_arn = aws_lb_target_group.TG_ALB.arn
    }
}