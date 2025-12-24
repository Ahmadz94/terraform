# --- Ubuntu 24.04 AMI ---
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

# --- Security Group: ALB ---
resource "aws_security_group" "alb_sg" {
  name        = "tf-easy-alb-sg"
  description = "ALB SG"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # allow browser access
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# --- Security Group: Instances ---
resource "aws_security_group" "instance_sg" {
  name        = "tf-easy-instance-sg"
  description = "Instance SG"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH from your IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["79.177.151.90/32"]
  }

  ingress {
    description     = "HTTP from ALB"
    from_port       = 80
    to_port         = 80
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
}

# --- User data ---
locals {
  user_data = <<-EOF
    #!/bin/bash
    set -euxo pipefail

    apt-get update -y
    apt-get install -y docker.io

    systemctl enable --now docker
    usermod -aG docker ubuntu || true

    docker rm -f hostname-docker 2>/dev/null || true
    docker pull adongy/hostname-docker
    docker run -d --name hostname-docker --restart unless-stopped -p 80:3000 adongy/hostname-docker
  EOF
}

# --- EC2 instances ---
resource "aws_instance" "a" {
  ami                         = data.aws_ami.ubuntu_2404.id
  instance_type               = "t3a.micro"
  subnet_id                   = aws_subnet.public_a.id
  vpc_security_group_ids      = [aws_security_group.instance_sg.id]
  key_name                    = "AWS-PC"
  associate_public_ip_address = true
  user_data                   = local.user_data

  tags = { Name = "tf-easy-ec2-a" }
}

resource "aws_instance" "b" {
  ami                         = data.aws_ami.ubuntu_2404.id
  instance_type               = "t3a.micro"
  subnet_id                   = aws_subnet.public_b.id
  vpc_security_group_ids      = [aws_security_group.instance_sg.id]
  key_name                    = "AWS-PC"
  associate_public_ip_address = true
  user_data                   = local.user_data

  tags = { Name = "tf-easy-ec2-b" }
}

# --- Application Load Balancer ---
resource "aws_lb" "app" {
  name               = "tf-easy-alb"
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.public_a.id, aws_subnet.public_b.id]

  tags = { Name = "tf-easy-alb" }
}

resource "aws_lb_target_group" "tg" {
  name     = "tf-easy-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    path                = "/"
    matcher             = "200-399"
    interval            = 15
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = { Name = "tf-easy-tg" }
}

resource "aws_lb_target_group_attachment" "a" {
  target_group_arn = aws_lb_target_group.tg.arn
  target_id        = aws_instance.a.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "b" {
  target_group_arn = aws_lb_target_group.tg.arn
  target_id        = aws_instance.b.id
  port             = 80
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg.arn
  }
}

output "alb_dns_name" {
  value = aws_lb.app.dns_name
}
