locals {
  aws_region = "us-east-1"
}

provider "aws" {
  region = local.aws_region
}

terraform {
  backend "s3" {
    key = "tf-example/stg/services/webserver-cluster/terrform.tfstate"
  }
}

module "webserver_cluster" {
  source                 = "../../../modules/services/webserver-cluster"
  aws_region             = local.aws_region
  cluster_name           = "webservers-stg"
  db_remote_state_bucket = "etm-terraform-state"
  db_remote_state_key    = "tf-example/stg/data-store/mysql/terraform.tfstate"
  instance_type          = "t2.micro"
  min_size               = 2
  max_size               = 2
}

# An extra custom I/O port beyond what the module provides.
resource "aws_security_group_rule" "allow_inbound_extra" {
  type              = "ingress"
  security_group_id = module.webserver_cluster.alb_security_group_id

  from_port   = 12345
  to_port     = 12345
  protocol    = "tcp"         # var/local?
  cidr_blocks = ["0.0.0.0/0"] # var/local?
}
