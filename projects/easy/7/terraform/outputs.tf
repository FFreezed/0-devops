output "server_public_ip" {
    description = "The Public IP address of your EC2 application server"
    value       = aws_instance.server.public_ip
}

output "ecr_repository_url" {
  description = "The URL registry endpoint of your AWS ECR container iamge repository"
  value       = aws_ecr_repository.app_repo.repository_url
}
