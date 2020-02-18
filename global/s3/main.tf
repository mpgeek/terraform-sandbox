terraform {
  backend "s3" {
    key = "tf-example/global/s3/terraform.tfstate"
  }
}

# S3 bucket for remote state storage.
resource "aws_s3_bucket" "example_tf_state" {
  ## Do this when its real.
  # lifecycle {
  #   prevent_destroy = true
  # }

  versioning {
    enabled = true
  }

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }
}

resource "aws_dynamodb_table" "example_tf_locks" {
  name         = "example"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}
