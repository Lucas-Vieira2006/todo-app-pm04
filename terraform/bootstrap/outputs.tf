output "state_bucket" {
  description = "Bucket do Terraform State. Configure como variável TF_STATE_BUCKET no GitHub."
  value       = aws_s3_bucket.state.bucket
}

output "backup_bucket" {
  description = "Bucket dos backups do MongoDB. Configure como variável BACKUP_BUCKET no GitHub."
  value       = aws_s3_bucket.backups.bucket
}

output "github_actions_role_arn" {
  description = "ARN do papel assumido via OIDC. Configure como variável AWS_ROLE_ARN no GitHub."
  value       = aws_iam_role.github_actions.arn
}

output "aws_region" {
  description = "Região. Configure como variável AWS_REGION no GitHub."
  value       = var.aws_region
}
