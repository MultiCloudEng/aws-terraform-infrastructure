output "state_bucket" {
  description = "S3 bucket holding the main configuration's state."
  value       = aws_s3_bucket.state.bucket
}

output "github_plan_role_arn" {
  description = "Set as GitHub repository variable AWS_PLAN_ROLE_ARN."
  value       = aws_iam_role.github_plan.arn
}

output "github_apply_role_arn" {
  description = "Set as GitHub variable AWS_APPLY_ROLE_ARN (on the production environment)."
  value       = aws_iam_role.github_apply.arn
}
