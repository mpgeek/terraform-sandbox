locals {
  aws_region = "us-east-1"
}

provider "aws" {
  region = local.aws_region
}

terraform {
  backend "s3" {
    key = "tf-example/prd/services/webserver-cluster/terrform.tfstate"
  }
}

module "webserver_cluster" {
  source                 = "../../../modules/services/webserver-cluster"
  aws_region             = local.aws_region
  cluster_name           = "webservers-prd"
  db_remote_state_bucket = "etm-terraform-state"
  db_remote_state_key    = "tf-example/prd/data-store/mysql/terraform.tfstate"
  instance_type          = "t2.micro"
  min_size               = 2
  max_size               = 8
}

resource "aws_autoscaling_schedule" "scale_out_business_hours" {
  scheduled_action_name  = "scale-out-during-business-hours"
  min_size               = 2
  max_size               = 8
  desired_capacity       = 8
  recurrence             = "0 9 * * *"
  autoscaling_group_name = module.webserver_cluster.asg_name
}

resource "aws_autoscaling_schedule" "scale_in_off_hours" {
  scheduled_action_name  = "scale-in-during-off-hours"
  min_size               = 2
  max_size               = 8
  desired_capacity       = 2
  recurrence             = "0 17 * * *"
  autoscaling_group_name = module.webserver_cluster.asg_name
}
