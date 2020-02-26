output "address" {
  description = "Database endpoint."
  value       = aws_db_instance.example.address
}

output "port" {
  description = "Database port."
  value       = aws_db_instance.example.port
}
