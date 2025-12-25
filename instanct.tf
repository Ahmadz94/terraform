# --- Ubuntu 24.04
data "aws_ami" "ubuntu_2404" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# --- SG-alb
resource "aws_security_group" "alb_sg" {
  name        = "${var.project_name}-alb-sg"
  description = "ALB SG"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP from internet"
    from_port   = var.app_port
    to_port     = var.app_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-alb-sg" }
}

# --- SG-instances
resource "aws_security_group" "instance_sg" {
  name        = "${var.project_name}-instance-sg"
  description = "Instance SG"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.ssh_cidr_blocks
  }

  ingress {
    description     = "HTTP from ALB"
    from_port       = var.app_port
    to_port         = var.app_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-instance-sg" }
}

# --- Userdata
locals {
  user_data = <<-EOF
    #!/bin/bash
    set -euxo pipefail

    apt-get update -y
    apt-get install -y docker.io

    systemctl enable --now docker
    usermod -aG docker ubuntu || true

    docker rm -f ${var.docker_container_name} 2>/dev/null || true
    docker pull ${var.docker_image}
    docker run -d --name ${var.docker_container_name} --restart unless-stopped -p ${var.app_port}:${var.container_internal_port} ${var.docker_image}
  EOF
}

# --- EC2
resource "aws_instance" "a" {
  ami                         = data.aws_ami.ubuntu_2404.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public_a.id
  vpc_security_group_ids      = [aws_security_group.instance_sg.id]
  key_name                    = var.aws_key_name
  associate_public_ip_address = true
  user_data                   = local.user_data

  tags = { Name = "${var.instance_name}-a" }
}

resource "aws_instance" "b" {
  ami                         = data.aws_ami.ubuntu_2404.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public_b.id
  vpc_security_group_ids      = [aws_security_group.instance_sg.id]
  key_name                    = var.aws_key_name
  associate_public_ip_address = true
  user_data                   = local.user_data

  tags = { Name = "${var.instance_name}-b" }
}

# --- ALB
resource "aws_lb" "app" {
  name               = var.alb_name
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.public_a.id, aws_subnet.public_b.id]

  tags = { Name = var.alb_name }
}

resource "aws_lb_target_group" "tg" {
  name     = var.target_group_name
  port     = var.app_port
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    path                = var.health_check_path
    matcher             = "200-399"
    interval            = var.health_check_interval
    timeout             = var.health_check_timeout
    healthy_threshold   = var.healthy_threshold
    unhealthy_threshold = var.unhealthy_threshold
  }

  tags = { Name = var.target_group_name }
}

resource "aws_lb_target_group_attachment" "a" {
  target_group_arn = aws_lb_target_group.tg.arn
  target_id        = aws_instance.a.id
  port             = var.app_port
}

resource "aws_lb_target_group_attachment" "b" {
  target_group_arn = aws_lb_target_group.tg.arn
  target_id        = aws_instance.b.id
  port             = var.app_port
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app.arn
  port              = var.app_port
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg.arn
  }
}

output "alb_dns_name" {
  value = aws_lb.app.dns_name
}
