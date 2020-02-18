terraform {
  backend "s3" {
    key = "tf-example/stg/services/terraform.tfstate"
  }
}

provider "aws" {
  region = "us-east-1"
}

# Lookup and use the "default" VPC.
data "aws_vpc" "default" {
  default = true
}

# Lookup VPC subnets.
data "aws_subnet_ids" "default" {
  vpc_id = data.aws_vpc.default.id
}

# Get db meta from db state.
data "terraform_remote_state" "db" {
  backend = "s3"

  # @TODO: template or variableize this.
  config = {
    bucket = "etm-terraform-state"
    key = "tf-example/stg/data-store/mysql/terraform.tfstate"
    region = "us-east-1"
  }
}

resource "aws_security_group" "example" {
  name = "terraform-example-instance"

  ingress {
    from_port   = var.webserver_port
    to_port     = var.webserver_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

data "template_file" "user_data" {
  template = file("user-data.sh")

  vars = {
    webserver_port = var.webserver_port

    # Since we have data-store/mysql/outputs.tf.
    db_address = data.terraform_remote_state.db.outputs.address
    db_port = data.terraform_remote_state.db.outputs.port
  }
}

resource "aws_launch_configuration" "example" {
  image_id        = "ami-08bc77a2c7eb2b1da"
  instance_type   = "t2.micro"
  security_groups = [aws_security_group.example.id]

  user_data = data.template_file.user_data.rendered

  # Required when using launch configs with autoscaling groups.
  # @see https://www.terraform.io/docs/providers/aws/r/launch_configuration.html#using-with-autoscaling-groups
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "example" {
  launch_configuration = aws_launch_configuration.example.name

  # Set subnets to those used by the VPC via lookup.
  vpc_zone_identifier = data.aws_subnet_ids.default.ids

  # Use the ALB target group.
  target_group_arns = [aws_lb_target_group.asg.arn]

  # Use the target gruop's health check.
  health_check_type = "ELB"

  min_size = 2
  max_size = 8

  tag {
    key                 = "Name"
    value               = "terraform-example-asg"
    propagate_at_launch = true
  }
}

resource "aws_lb" "example" {
  name               = "terraform-asg-example"
  load_balancer_type = "application"

  # Set subnets to those used by the VPC via lookup.
  subnets = data.aws_subnet_ids.default.ids

  # Set security group to the ALB's security group.
  security_groups = [aws_security_group.alb.id]
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.example.arn
  port              = 80
  protocol          = "HTTP"

  # Return a 404 when a request doesn't match a listener rule.
  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "404: page not found"
      status_code  = 404
    }
  }
}

# The load balancer needs it's own security group.
resource "aws_security_group" "alb" {
  name = "terraform-example-alb"

  # Allow inbound HTTP requests.
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound requests.
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_lb_target_group" "asg" {
  name     = "terraform-asg-example"
  port     = var.webserver_port
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default.id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 15
    timeout             = 3
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_listener_rule" "asg" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 100

  condition {
    path_pattern {
      values = ["*"]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.asg.arn
  }
}
