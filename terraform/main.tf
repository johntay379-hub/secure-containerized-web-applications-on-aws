terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Core Secure Network Isolation Blueprint
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "secure-production-vpc"
    Environment = var.environment
  }
}

# Least-Privilege Application Security Group
resource "aws_security_group" "app_sg" {
  name        = "app-container-security-group"
  description = "TFSEC-compliant least privilege network boundary control"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "Allow inbound container engine application traffic"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"] # Restricted to internal VPC architecture only
  }

  egress {
    description = "Allow container egress for patches"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "secure-app-sg"
  }
}

# Fetch the latest verified Ubuntu 24.04 LTS AMI ID automatically
data "aws_ami" "ubuntu" {
  most_recent = true
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-noble-24.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  owners = ["099720109477"] # Official Canonical Owner ID
}

# Secure Isolated EC2 Instance
resource "aws_instance" "web_server" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"
  subnet_id     = aws_subnet.private.id # Placed safely inside the private subnet

  vpc_security_group_ids = [aws_security_group.app_sg.id]

  # Hardening: Force IMDSv2 (Prevents SSRF cloud credential theft attacks)
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  # Root Volume Hardening
  root_block_device {
    volume_size           = 20
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  # Automated Bootstrapping Script: Native Docker Installation
  user_data = <<-EOF
              #!/bin/bash
              apt-get update -y
              apt-get install -y apt-transport-https ca-certificates curl software-properties-common
              curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
              add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
              apt-get update -y
              apt-get install -y docker-ce docker-ce-cli containerd.io
              systemctl enable docker
              systemctl start docker
              EOF

  tags = {
    Name        = "secure-production-server"
    Environment = var.environment
  }
}