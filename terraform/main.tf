terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# =========================================================================
# SECURITY GROUPS (The Firewalls)
# =========================================================================

resource "aws_security_group" "ec2_sg" {
  name        = "secure-app-ec2-sg"
  description = "Allow inbound application traffic"
  vpc_id      = aws_vpc.main.id

  # Inbound FastAPI traffic
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # In production, restrict this to an ALB!
  }

  # Outbound traffic (needed to download patches and Docker images)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "secure-app-security-group"
  }
}

# =========================================================================
# AWS ECR (Our Secure Container Vault)
# =========================================================================

resource "aws_ecr_repository" "app_repo" {
  name                 = "secure-python-app"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

# =========================================================================
# IAM PROFILE (Gives EC2 permission to pull from ECR)
# =========================================================================

resource "aws_iam_role" "ec2_role" {
  name = "secure-ec2-ecr-reader-role"

assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

# 1. This gives your EC2 server permission to pull Docker containers from ECR
resource "aws_iam_role_policy_attachment" "ecr_read" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# 2. This allows AWS Systems Manager to securely send deployment commands
resource "aws_iam_role_policy_attachment" "ssm_managed" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# 3. This links the IAM role to a profile that the EC2 instance can actually wear
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "secure-ec2-instance-profile"
  role = aws_iam_role.ec2_role.name
}

# =========================================================================
# COMPUTE LAYER (The Virtual Machine)
# =========================================================================

# Fetch latest stable Ubuntu 22.04 LTS AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  owners = ["099720109477"] # Canonical
}

resource "aws_instance" "web" {
  ami                  = data.aws_ami.ubuntu.id
  instance_type        = "t3.micro"
  subnet_id            = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name

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
              add-apt-repository -y "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
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
