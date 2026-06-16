output "instance_public_ip" {
  description = "The public IPv4 address needed for your GitHub Actions deployment target."
  value       = aws_instance.server.public_ip
}