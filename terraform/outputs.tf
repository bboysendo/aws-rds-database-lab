output "db_instance_endpoint" {
  description = "Connection endpoint (host:port) for the RDS instance."
  value       = aws_db_instance.this.endpoint
}

output "db_instance_identifier" {
  description = "RDS instance identifier."
  value       = aws_db_instance.this.identifier
}

output "secret_arn" {
  description = "ARN of the Secrets Manager secret holding the auto-generated master password. Never printed in plain text."
  value       = aws_db_instance.this.master_user_secret[0].secret_arn
}

output "app_security_group_id" {
  description = "Security group ID to attach to any instance that needs database access."
  value       = aws_security_group.app.id
}
