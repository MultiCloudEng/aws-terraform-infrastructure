output "asg_name" {
  description = "Name of the Auto Scaling Group."
  value       = aws_autoscaling_group.server.name
}

output "launch_template_id" {
  description = "ID of the launch template."
  value       = aws_launch_template.server.id
}

output "launch_template_metadata_http_tokens" {
  description = "IMDS token setting of the launch template (\"required\" = IMDSv2 only)."
  value       = aws_launch_template.server.metadata_options[0].http_tokens
}

output "launch_template_root_encrypted" {
  description = "Whether the root EBS volume is encrypted."
  value       = aws_launch_template.server.block_device_mappings[0].ebs[0].encrypted == "true"
}
