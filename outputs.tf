output "web_asg_name" {
  description = "Auto Scaling Group name for the web service."
  value       = module.web.asg_name
}

output "api_asg_name" {
  description = "Auto Scaling Group name for the api service."
  value       = module.api.asg_name
}

output "security_group_id" {
  description = "Security group attached to the instances (no inbound rules)."
  value       = aws_security_group.instances.id
}

output "instance_role_name" {
  description = "IAM role used by the instances for SSM Session Manager."
  value       = aws_iam_role.instance.name
}
