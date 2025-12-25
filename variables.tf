variable "project_name" {
  description = "name used for tagging and resource naming"
  type        = string
  default     = "terraform-easy"
}

variable "aws_key_name" {
  description = "Existing EC2 key pair name in AWS"
  type        = string
  default     = "AWS-PC"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "instance_name" {
  description = "Base Name tag for instances (will be suffixed a/b)"
  type        = string
  default     = "tf-easy-instance"
}

variable "ssh_cidr_blocks" {
  description = "CIDRs allowed to SSH into instances"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "vpc_cidr" {
  description = "VPC CIDR"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_a_cidr" {
  description = "Public subnet A CIDR"
  type        = string
  default     = "10.0.1.0/24"
}

variable "public_subnet_b_cidr" {
  description = "Public subnet B CIDR"
  type        = string
  default     = "10.0.2.0/24"
}

variable "az_index_a" {
  description = "subnet A"
  type        = number
  default     = 0
}

variable "az_index_b" {
  description = "subnet B"
  type        = number
  default     = 1
}

variable "alb_name" {
  description = "ALB name"
  type        = string
  default     = "tf-easy-alb"
}

variable "target_group_name" {
  description = "Target group name"
  type        = string
  default     = "tf-easy-tg"
}

variable "app_port" {
  description = "App port "
  type        = number
  default     = 80
}

variable "health_check_path" {
  description = "ALB target group health check path"
  type        = string
  default     = "/"
}

variable "health_check_interval" {
  type    = number
  default = 15
}

variable "health_check_timeout" {
  type    = number
  default = 5
}

variable "healthy_threshold" {
  type    = number
  default = 2
}

variable "unhealthy_threshold" {
  type    = number
  default = 2
}

variable "docker_image" {
  description = "Docker image "
  type        = string
  default     = "adongy/hostname-docker"
}

variable "docker_container_name" {
  description = "Container name"
  type        = string
  default     = "hostname-docker"
}

variable "container_internal_port" {
  description = "Port exposed"
  type        = number
  default     = 3000
}
