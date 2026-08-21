#----------------------------------------
# Application Load Balancer
#----------------------------------------

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

#----------------------------------------
# IAM ROLE + INSTANCE PROFILE (PRO SSM SESSION MANAGER)
#----------------------------------------
resource "aws_iam_role" "iam_role" {
  name = "Iam-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "iam_attachment" {
  role       = aws_iam_role.iam_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "Project_profile" {
  name = "project-profile"
  role = aws_iam_role.iam_role.name
}

#----------------------------------------
# LAUNCH TEMPLATE & AUTO SCALLING
#----------------------------------------

data "aws_ami" "image_id"{
    most_recent = true
    owners = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_launch_template" "Project_template"{
    name = "Project-Template"
    image_id = data.aws_ami.image_id.id
    instance_type = "t3.micro"

    iam_instance_profile {
      name = aws_iam_instance_profile.Project_profile.name
    }

    vpc_security_group_ids = [var.instance_security_group_id]

    user_data = base64encode(<<-EOF
        #!/bin/bash
        dnf update -y
        dnf install -y httpd
        systemctl enable httpd
        systemctl start httpd
        echo "<h1>Hello from $(hostname -f)</h1>" > /var/www/html/index.html
    EOF
    )

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "Project Launche Template"
    }
  }
}