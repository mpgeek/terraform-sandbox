provider "aws" {
  region = "us-east-1"
}

resource "aws_instance" "example" {
  ami           = "ami-08bc77a2c7eb2b1da"
  instance_type = "t2.micro"

  tags = {
    Name = "terraform-example"
  }
}
