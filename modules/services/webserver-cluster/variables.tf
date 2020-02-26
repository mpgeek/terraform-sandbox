variable "aws_region" {
  default = ""
}

variable "cluster_name" {
  description = "The name to use for all cluster resources."
  type        = string
}

variable "db_remote_state_bucket" {
  description = "The name of the S3 bucket for the database's remote state."
  type        = string
}

variable "db_remote_state_key" {
  description = "The path for the dtabases remote state."
  type        = string
}

variable "webserver_port" {
  description = "The port the webserver will use for HTTP requests."
  type        = number
  default     = 8080
}

variable "instance_type" {
  description = "Type of ec2 instance to run (e.g. t2.micro)"
  type        = string
}

variable "min_size" {
  description = "The minimum numbe of ec2 instances in the ASG."
  default     = 2
}

variable "max_size" {
  description = "The maximum nuber of ec2 instances in the ASG."
  default     = 2
}
