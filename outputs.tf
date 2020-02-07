output "public_ip" {
  description = "The public IP address of the webserver."
  value       = aws_instance.example.public_ip

}
