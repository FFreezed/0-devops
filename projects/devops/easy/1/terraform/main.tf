# ---------------------------------------------------------------------------
# 1. Terraform Settings & Provider Configuration
# ---------------------------------------------------------------------------
terraform {
    required_version = ">= 1.5.0"
    required_providers {
        aws = {
        source  = "hashicorp/aws"
        version = "~> 6.0"
        }
    }
}

provider "aws" {
    region = "ap-southeast-3" 
}

# ---------------------------------------------------------------------------
# 2. Local Variables 
# ---------------------------------------------------------------------------
locals {
    my_local_ip = "172.26.82.237/32" 
    environment = "lab-static-webserver"
}

# ---------------------------------------------------------------------------
# 3. Dynamic AMI Data Source (Ubuntu 24.04 LTS)
# ---------------------------------------------------------------------------
data "aws_ami" "ubuntu_24_04" {
    most_recent = true
    owners      = ["099720109477"]

    filter {
        name   = "name"
        values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
    }
}

# ---------------------------------------------------------------------------
# 4. Networking Security Group
# ---------------------------------------------------------------------------
data "aws_vpc" "default" {
    default = true
}

resource "aws_security_group" "web_sg" {
    name        = "${local.environment}-sg"
    description = "Allow restricted SSH and public HTTP"
    vpc_id      = data.aws_vpc.default.id

    ingress {
        description = "SSH from allowed workspace only"
        from_port   = 22
        to_port     = 22
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    ingress {
        description = "HTTP traffic from anywhere"
        from_port   = 80
        to_port     = 80
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
        description = "Allow all outbound traffic"
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }

    tags = {
        Name = "${local.environment}-sg"
    }
}

# ---------------------------------------------------------------------------
# 5. On-Demand EC2 Instance with User Data Bootstrapping
# ---------------------------------------------------------------------------
resource "aws_instance" "server" {
    ami                         = data.aws_ami.ubuntu_24_04.id
    instance_type               = "t3.micro" 
    associate_public_ip_address = true       
    vpc_security_group_ids      = [aws_security_group.web_sg.id]
    key_name                    = "demo-key-pair"

    root_block_device {
        volume_size           = 8
        volume_type           = "gp3"
        encrypted             = true
        delete_on_termination = true
    }

    user_data = <<-EOF
                #!/bin/bash
                sudo apt-get update -y
                sudo apt-get install -y docker.io docker-compose
                sudo systemctl start docker
                sudo systemctl enable docker
                
                # Allow the default ubuntu user to run docker commands without sudo
                sudo usermod -aG docker ubuntu
                EOF

    tags = {
        Name        = "${local.environment}-server"
        Environment = local.environment
    }
}