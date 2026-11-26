# Perfil da VM do banco: envia e lê backups apenas no prefixo do próprio ambiente
data "aws_iam_policy_document" "ec2_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "db" {
  name               = "${local.name_prefix}-db"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
}

data "aws_iam_policy_document" "db_backup" {
  statement {
    sid       = "ObjetosDoAmbiente"
    actions   = ["s3:PutObject", "s3:GetObject"]
    resources = ["arn:aws:s3:::${var.backup_bucket_name}/${var.environment}/*"]
  }

  statement {
    sid       = "ListarPrefixoDoAmbiente"
    actions   = ["s3:ListBucket"]
    resources = ["arn:aws:s3:::${var.backup_bucket_name}"]
    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values   = ["${var.environment}/*"]
    }
  }
}

resource "aws_iam_role_policy" "db_backup" {
  name   = "${local.name_prefix}-db-backup"
  role   = aws_iam_role.db.id
  policy = data.aws_iam_policy_document.db_backup.json
}

resource "aws_iam_instance_profile" "db" {
  name = "${local.name_prefix}-db"
  role = aws_iam_role.db.name
}
