variable "vpc_id"{
    description = "ID VPC"
    type = string
}

variable "alb_security_group_id" {
  description = "ID SG ALB"
  type        = string
}

variable "instance_security_group_id" {
  description = "ID SG INSTANCE"
  type        = string
}

variable "public_subnets_ids"{
    description = "ID from Public subnets"
    type = list(string)
}

variable "private_subnets_ids"{
    description = "ID from Private subnets"
    type = list(string)
}