#----------------------------------------
# Security Groups
#----------------------------------------

#   ALB SG
resource "aws_security_group" "SG_ALB"{
    name = "SG-ALB"
    description = "Security Group for ALB"
    vpc_id = var.vpc_id

    tags = {
      Name = "Security Group (ALB)"
    }
}

resource "aws_vpc_security_group_ingress_rule" "allow_http"{
    security_group_id = aws_security_group.SG_ALB.id
    cidr_ipv4 = "0.0.0.0/0"
    from_port = 80
    ip_protocol = "tcp"
    to_port = 80
}

#   Instance SG
resource "aws_security_group" "SG_INSTANCE"{
    name = "SG-INSTANCE"
    description = "Security Group for Instance"
    vpc_id = var.vpc_id

    tags = {
      Name = "Security Group (Instance)"
    }
}

resource "aws_vpc_security_group_ingress_rule" "allow_alb"{
    security_group_id = aws_security_group.SG_INSTANCE.id
    referenced_security_group_id = aws_security_group.SG_ALB.id
    from_port = 80
    ip_protocol = "tcp"
    to_port = 80
}