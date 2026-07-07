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
    environment = "metrics-scraping"
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
        description = "Grafana Dashboard"
        from_port   = 3000
        to_port     = 3000
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
                # Redirect all output to log files for easy troubleshooting later
                exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

                echo "=== Starting Docker & Docker Compose Installation ==="

                # 1. Update system package index
                apt-get update -y
                apt-get upgrade -y

                # 2. Install prerequisite packages
                apt-get install -y ca-certificates curl gnupg lsb-release

                # 3. Add Docker's official GPG key
                install -m 0755 -d /etc/apt/keyrings
                curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
                chmod a+r /etc/apt/keyrings/docker.gpg

                # 4. Set up the stable Docker repository
                # 🟢 FIXED: Fixed the folder path to .list.d/ and flattened the line to avoid string parsing issues
                echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

                # 5. Install Docker Engine and the Docker Compose plugin
                apt-get update -y
                apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

                # 6. Enable and start the Docker service
                systemctl enable docker
                systemctl start docker

                # 7. Add the default cloud-user (ubuntu) to the docker group 
                usermod -aG docker ubuntu

                echo "=== Docker Installation Completed Successfully ==="
                EOF

    tags = {
        Name        = "${local.environment}-server"
        Environment = local.environment
    }
}
