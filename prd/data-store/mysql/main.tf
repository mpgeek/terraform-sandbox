locals {
  aws_region = "us-east-1"
  db_instance_id_prefix = "tf-example-prd"
}

terraform {
  backend "s3" {
    key = "tf-example/prd/data-store/mysql/terraform.tfstate"
  }
}

provider "aws" {
  region = local.aws_region
}

resource "aws_db_instance" "example" {
  identifier_prefix = "${local.db_instance_id_prefix}-"
  engine            = "mysql"
  instance_class    = "db.t2.micro"
  allocated_storage = 10

  name     = "example_database"
  username = "dbadmin"
  password = "changeme123"

  ## Use AWS Secrets instead of using "password".
  #password = data.aws_secretsmanager_secret_version.db_password.secret_string

  # Skipping final snapshot is probably a bad idea for a production system.
  skip_final_snapshot       = true
  final_snapshot_identifier = "${local.db_instance_id_prefix}-snapshot-final"
}

# Requires creating a secret in the UI _after_ the db has been created.
# data "aws_secretsmanager_secret_version" "db_password" {
#   secret_id = "tf-example"
# }
