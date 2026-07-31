output "instance_public_ip" {
  description = "Public IPv4 address."
  value       = aws_instance.server.public_ip
}