# 1. Terraform Settings & Provider Configuration
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

# 2. Local Variables 
locals {
    # my_local_ip = "172.26.82.237/32" 
    environment = "1node-k3s-argocd"
}

# 3. Dynamic AMI Data Source (Ubuntu 24.04 LTS)
data "aws_ami" "ubuntu_24_04" {
    most_recent = true
    owners      = ["099720109477"]

    filter {
        name   = "name"
        values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
    }
}

# 4. Networking Security Group
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

    ingress {
        description = "ArgoCD Web UI Access"
        from_port   = 8080
        to_port     = 8080
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

# 5. Spot EC2 Instance with K3s Cluster Bootstrapping
resource "aws_instance" "server" {
    ami                         = data.aws_ami.ubuntu_24_04.id
    instance_type               = "t3.small" 
    associate_public_ip_address = true       
    vpc_security_group_ids      = [aws_security_group.web_sg.id]
    key_name                    = "demo-key-pair"

    # Instance Spot Block
    instance_market_options {
        market_type = "spot"
        spot_options {
            max_price = "0.02"
        }
    } 

    root_block_device {
        volume_size           = 15 
        volume_type           = "gp3"
        encrypted             = true
        delete_on_termination = true
    }

    user_data = <<-EOF
                #!/bin/bash
                sudo apt-get update -y

                # 1. Install K3s and natively configure group read permissions for the config file
                curl -sfL https://get.k3s.io | sh -s - --disable traefik --write-kubeconfig-mode 644

                # 2. Wait a few seconds for the file system layers to settle
                sleep 15

                # 3. Create the home config path for the ubuntu user safely
                mkdir -p /home/ubuntu/.kube
                cp /etc/rancher/k3s/k3s.yaml /home/ubuntu/.kube/config
                
                # 4. Correct the file ownership explicitly
                chown -R ubuntu:ubuntu /home/ubuntu/.kube
                chmod 600 /home/ubuntu/.kube/config

                # 5. Permanently append the KUBECONFIG environment variable path to the profile shell
                echo "export KUBECONFIG=/home/ubuntu/.kube/config" >> /home/ubuntu/.bashrc
                EOF

    tags = {
        Name        = "${local.environment}-server"
        Environment = local.environment
    }
}