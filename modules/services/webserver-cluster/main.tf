locals {
  port_http    = 80
  port_any     = 0
  protocol_any = "-1"
  protocol_tcp = "tcp"
  cidr_all_ips = ["0.0.0.0/0"]
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

  config = {
    region = var.aws_region
    bucket = var.db_remote_state_bucket
    key    = var.db_remote_state_key
  }
}

resource "aws_security_group" "instance" {
  name = "${var.cluster_name}-instance"

  ingress {
    from_port   = var.webserver_port
    to_port     = var.webserver_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

data "template_file" "user_data" {
  template = file("${path.module}/user-data.sh")

  vars = {
    webserver_port = var.webserver_port

    # Since we have data-store/mysql/outputs.tf.
    db_address = data.terraform_remote_state.db.outputs.address
    db_port    = data.terraform_remote_state.db.outputs.port
  }
}

resource "aws_launch_configuration" "example" {
  image_id        = "ami-08bc77a2c7eb2b1da"
  instance_type   = var.instance_type
  security_groups = [aws_security_group.instance.id]

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

  min_size = var.min_size
  max_size = var.max_size

  tag {
    key                 = "Name"
    value               = var.cluster_name
    propagate_at_launch = true
  }
}

resource "aws_lb" "example" {
  name               = "${var.cluster_name}-lb"
  load_balancer_type = "application"

  # Set subnets to those used by the VPC via lookup.
  subnets = data.aws_subnet_ids.default.ids

  # Set security group to the ALB's security group.
  security_groups = [aws_security_group.alb.id]
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.example.arn
  port              = local.port_http
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
  name = "${var.cluster_name}-alb"
}

resource "aws_security_group_rule" "allow_http_inbound" {
  type              = "ingress"
  security_group_id = aws_security_group.alb.id

  from_port   = local.port_http
  to_port     = local.port_http
  protocol    = local.protocol_tcp
  cidr_blocks = local.cidr_all_ips
}

resource "aws_security_group_rule" "allow_all_outbound" {
  type              = "egress"
  security_group_id = aws_security_group.alb.id

  from_port   = local.port_any
  to_port     = local.port_any
  protocol    = local.protocol_any
  cidr_blocks = local.cidr_all_ips
}

resource "aws_lb_target_group" "asg" {
  name     = "${var.cluster_name}-asg"
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
