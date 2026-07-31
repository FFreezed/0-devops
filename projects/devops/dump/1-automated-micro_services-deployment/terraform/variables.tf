variable "aws_region" {
    type    = string
    description = "The AWS region to deploy resources in"
    default = "ap-southeast-3"
}

variable "my_ip" {
    type    = string
    description = "IP address of the user's workspace for SSH access (in CIDR notation)"
    default = "103.18.34.130/32"
}

variable "environment" {
    type    = string
    description = "Application environment tag."
    default = "dev"
}

variable "instance_type" {
    type    = string
    description = "The size of the EC2 instance"
    default = "t3.micro"
}

variable "key_name" {
    type        = string
    description = "The name of the existing AWS SSH Key Pair to access the instance."
    default     = "demo-key-pair"
}