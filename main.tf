provider "aws" {
  region = "us-east-1"
}

resource "aws_security_group" "example" {
  name = "terraform-example-instance"

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "example" {
  ami                    = "ami-08bc77a2c7eb2b1da"
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.example.id]

  # Boot-time script.
  user_data = <<-EOF
              #!/bin/bash
              echo "Hello, World!" > index.html
              nohup busybox httpd -f -p 8080 &
              EOF

  tags = {
    Name = "terraform-example"
  }
}
