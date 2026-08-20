terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

module "network" {
  source = "./modules/network"
}

module "security" {
  source = "./modules/security"

  vpc_id = module.network.vpc_id
}

module "compute" {
  source = "./modules/compute"

  vpc_id = module.network.vpc_id
  private_subnets_ids = module.network.private_subnet_ids
  public_subnets_ids = module.network.public_subnet_ids
  alb_security_group_id = module.security.alb_security_group_id
  
}