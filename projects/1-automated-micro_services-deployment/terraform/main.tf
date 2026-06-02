# ---------------------------------------------------------------------------
# 1. Terraform Settings & Provider Configuration
# ---------------------------------------------------------------------------

terraform {
    required_version = ">= 1.5.0"
	required_providers {
		aws = {
			source = "hashicorp/aws"
			version = "~> 6.0"
		}
	}
}

provider "aws" {
	region = var.aws_region  
}

data "aws_vpc" "default" {
  default = true
}

# ---------------------------------------------------------------------------
# 2. Dynamic AMI Data Source (Ubuntu 24.04 LTS)
# ---------------------------------------------------------------------------
data "aws_ami" "ubuntu_24_04" {
    most_recent = true
    owners      = ["099720109477"]  # Canonical's AWS Account ID

    filter {
        name   = "name"
        values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
    }

    filter {
        name   = "virtualization-type"
        values = ["hvm"]
    }
}

# ---------------------------------------------------------------------------
# 3. Security Group Configuration
# ---------------------------------------------------------------------------

resource "aws_security_group" "web_telemetry_sg" {
    name        = "${var.environtment}-web-telemetry-sg"
    description = "Security group allowing SSH, HTTP, and Telemetry access"
    vpc_id      = data.aws_vpc.default.id

    # SSH Access restriced to the user's IP
    ingress {
        description      = "SSH from allowed workspace only"
        from_port        = 22
        to_port          = 22
        protocol         = "tcp"
        cidr_blocks      = [var.my_ip]
    }

    # HTTP Public Access
    ingress {
        description      = "HTTP from anywhere"
        from_port        = 80
        to_port          = 80
        protocol         = "tcp"
        cidr_blocks      = ["0.0.0.0/0"]
    }

    # Telemetry Access (Port 9090) from anywhere
    ingress {
        description      = "Telemetry access from anywhere"
        from_port        = 9090
        to_port          = 9090
        protocol         = "tcp"
        cidr_blocks      = ["0.0.0.0/0"]
    }

    # Default egress rule to allow all outbound traffic
    egress {
        description      = "Allow all outbound traffic"
        from_port        = 0
        to_port          = 0
        protocol         = "-1" # -1 means all protocols
        cidr_blocks      = ["0.0.0.0/0"]
    }

    tags = {
        Name       = "${var.environtment}-sg"
        Environment = var.environtment
    }
}


# ---------------------------------------------------------------------------
# 4. EC2 Instance Configuration
# ---------------------------------------------------------------------------

resource "aws_instance" "web_server" {
    ami           = data.aws_ami.ubuntu_24_04.id
    instance_type = var.instance_type
    vpc_security_group_ids = [aws_security_group.web_telemetry_sg.id]
    key_name      = var.key_name
    
    root_block_device {
        volume_size = 20
        volume_type = "gp3"
        encrypted   = true
        delete_on_termination = true
    }
    
    tags = {
        Name        = "${var.environtment}-ubuntu-server"
        Environment = var.environtment
    }
}