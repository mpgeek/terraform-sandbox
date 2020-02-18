terraform {
  backend "s3" {
    key = "tf-example/stg/data-store/mysql/terraform.tfstate"
  }
}

provider "aws" {
  region = "us-east-1"
}

# MySQL on RDS instance.
resource "aws_db_instance" "example" {
  identifier_prefix = "${var.db_instance_id_prefix}-"
  engine = "mysql"

  # 10 GB.
  allocated_storage = 10

  instance_class = "db.t2.micro"
  name = "example_database"
  username = "dbadmin"

  # Use AWS Secrets.
  password = data.aws_secretsmanager_secret_version.db_password.secret_string

  # Skipping final snapshot is probably a bad idea for a production system.
  skip_final_snapshot = true
  final_snapshot_identifier = "${var.db_instance_id_prefix}-snapshot-final"
}

# Requires creting a secret in the UI.
data "aws_secretsmanager_secret_version" "db_password" {
  secret_id = "tf-example"
}
