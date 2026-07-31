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

data "aws_ami" "ubuntu_24_04" {
    most_recent = true
    owners      = ["099720109477"]

    filter {
        name   = "name"
        values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
    }
}

locals {
    environment = "multi-stage-docker-kubernetes"
}

data "aws_vpc" "default" {
    default = true
}

resource "aws_security_group" "web_sg" {
    name        = "${local.environment}-sg"
    description = "Allow restricted SSH and public HTTP"
    vpc_id      = data.aws_vpc.default.id

    ingress {
        description = "SSH"
        from_port   = 22
        to_port     = 22
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    ingress {
        description = "TCP NodePort"
        from_port   = 30080 
        to_port     = 30080
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


resource "aws_instance" "server" {
    ami                         = data.aws_ami.ubuntu_24_04.id
    instance_type               = "t3.small" 
    associate_public_ip_address = true       
    vpc_security_group_ids      = [aws_security_group.web_sg.id]
    key_name                    = "demo-key-pair"

    instance_market_options {
        market_type = "spot"
        spot_options {
            max_price = "0.02"
        }
    } 

    root_block_device {
        volume_size           = 20 
        volume_type           = "gp3"
        encrypted             = true
        delete_on_termination = true
    }

    user_data = <<-EOF
                #!/bin/bash
                sudo apt-get update -y
                sudo apt-get install -y docker.io

                curl -sfL https://get.k3s.io | sh -s - --disable traefik --write-kubeconfig-mode 644

                sleep 20

                mkdir -p /home/ubuntu/.kube
                cp /etc/rancher/k3s/k3s.yaml /home/ubuntu/.kube/config
                
                chown -R ubuntu:ubuntu /home/ubuntu/.kube
                chmod 600 /home/ubuntu/.kube/config

                echo "export KUBECONFIG=/home/ubuntu/.kube/config" >> /home/ubuntu/.bashrc
                EOF

    tags = {
        Name        = "${local.environment}-server"
        Environment = local.environment
    }
}
