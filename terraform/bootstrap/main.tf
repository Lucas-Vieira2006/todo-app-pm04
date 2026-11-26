data "aws_caller_identity" "current" {}

locals {
  account_id         = data.aws_caller_identity.current.account_id
  state_bucket_name  = "${var.project}-tfstate-${local.account_id}"
  backup_bucket_name = "${var.project}-backups-${local.account_id}"
  oidc_provider_arn  = var.create_oidc_provider ? aws_iam_openid_connect_provider.github[0].arn : data.aws_iam_openid_connect_provider.github[0].arn
}

# ---------------------------------------------------------------------------
# Bucket do Terraform State (persistente, versionado, criptografado e privado)
# ---------------------------------------------------------------------------
resource "aws_s3_bucket" "state" {
  # Decisões de custo/escopo (documentadas em docs/decisoes-arquiteturais.md):
  #checkov:skip=CKV_AWS_18:Logs de acesso exigiriam outro bucket; acesso já é restrito ao papel da pipeline
  #checkov:skip=CKV_AWS_144:Replicação entre regiões dobraria o custo; versionamento atende à recuperação
  #checkov:skip=CKV_AWS_145:SSE-S3 (AES256) sem custo; chave KMS dedicada custaria US$ 1/mês
  #checkov:skip=CKV2_AWS_62:Notificações de eventos não são necessárias para o projeto
  bucket = local.state_bucket_name

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "state" {
  bucket                  = aws_s3_bucket.state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "state" {
  bucket = aws_s3_bucket.state.id
  rule {
    id     = "expirar-versoes-antigas"
    status = "Enabled"
    filter {}
    noncurrent_version_expiration {
      noncurrent_days = 90
    }
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# ---------------------------------------------------------------------------
# Bucket de backups do MongoDB (sobrevive à desativação dos ambientes)
# ---------------------------------------------------------------------------
resource "aws_s3_bucket" "backups" {
  # Decisões de custo/escopo (documentadas em docs/decisoes-arquiteturais.md):
  #checkov:skip=CKV_AWS_18:Logs de acesso exigiriam outro bucket; acesso já é restrito ao papel da pipeline
  #checkov:skip=CKV_AWS_144:Replicação entre regiões dobraria o custo; versionamento atende à recuperação
  #checkov:skip=CKV_AWS_145:SSE-S3 (AES256) sem custo; chave KMS dedicada custaria US$ 1/mês
  #checkov:skip=CKV2_AWS_62:Notificações de eventos não são necessárias para o projeto
  bucket = local.backup_bucket_name
}

resource "aws_s3_bucket_versioning" "backups" {
  bucket = aws_s3_bucket.backups.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "backups" {
  bucket = aws_s3_bucket.backups.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "backups" {
  bucket                  = aws_s3_bucket.backups.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "backups" {
  bucket = aws_s3_bucket.backups.id
  rule {
    id     = "retencao-backups"
    status = "Enabled"
    filter {}
    expiration {
      days = var.backup_retention_days
    }
    noncurrent_version_expiration {
      noncurrent_days = 7
    }
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# Os dois buckets só aceitam conexões TLS
data "aws_iam_policy_document" "tls_only" {
  for_each = {
    state   = aws_s3_bucket.state.arn
    backups = aws_s3_bucket.backups.arn
  }

  statement {
    sid     = "DenyInsecureTransport"
    effect  = "Deny"
    actions = ["s3:*"]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    resources = [each.value, "${each.value}/*"]
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "state" {
  bucket = aws_s3_bucket.state.id
  policy = data.aws_iam_policy_document.tls_only["state"].json
}

resource "aws_s3_bucket_policy" "backups" {
  bucket = aws_s3_bucket.backups.id
  policy = data.aws_iam_policy_document.tls_only["backups"].json
}

# ---------------------------------------------------------------------------
# OIDC: GitHub Actions assume um papel IAM sem chaves de acesso armazenadas
# ---------------------------------------------------------------------------
resource "aws_iam_openid_connect_provider" "github" {
  count          = var.create_oidc_provider ? 1 : 0
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
}

data "aws_iam_openid_connect_provider" "github" {
  count = var.create_oidc_provider ? 0 : 1
  url   = "https://token.actions.githubusercontent.com"
}

data "aws_iam_policy_document" "github_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [local.oidc_provider_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    # Somente jobs que rodam nos GitHub Environments do repositório autorizado
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = [for env in var.environments : "repo:${var.github_repository}:environment:${env}"]
    }
  }
}

resource "aws_iam_role" "github_actions" {
  name                 = "${var.project}-github-actions"
  description          = "Papel assumido pelas pipelines do ${var.github_repository}"
  assume_role_policy   = data.aws_iam_policy_document.github_trust.json
  max_session_duration = 3600
}

data "aws_iam_policy_document" "pipeline" {
  # Infraestrutura dos ambientes (VPC, sub-redes, SGs, EC2, EBS, EIP) restrita à região
  statement {
    sid       = "Ec2NaRegiao"
    actions   = ["ec2:*"]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "aws:RequestedRegion"
      values   = [var.aws_region]
    }
  }

  # Papel e perfil de instância da VM do banco (somente recursos com o prefixo do projeto)
  statement {
    sid = "IamDoProjeto"
    actions = [
      "iam:CreateRole", "iam:DeleteRole", "iam:GetRole", "iam:TagRole", "iam:UntagRole",
      "iam:UpdateRole", "iam:UpdateAssumeRolePolicy", "iam:ListRolePolicies",
      "iam:ListAttachedRolePolicies", "iam:ListInstanceProfilesForRole",
      "iam:PutRolePolicy", "iam:GetRolePolicy", "iam:DeleteRolePolicy",
      "iam:CreateInstanceProfile", "iam:DeleteInstanceProfile", "iam:GetInstanceProfile",
      "iam:TagInstanceProfile", "iam:AddRoleToInstanceProfile", "iam:RemoveRoleFromInstanceProfile",
    ]
    resources = [
      "arn:aws:iam::${local.account_id}:role/${var.project}-*",
      "arn:aws:iam::${local.account_id}:instance-profile/${var.project}-*",
    ]
  }

  statement {
    sid       = "PassarPapelParaEc2"
    actions   = ["iam:PassRole"]
    resources = ["arn:aws:iam::${local.account_id}:role/${var.project}-*"]
    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["ec2.amazonaws.com"]
    }
  }

  # Terraform State com lock nativo do S3
  statement {
    sid       = "StateListar"
    actions   = ["s3:ListBucket", "s3:GetBucketVersioning"]
    resources = [aws_s3_bucket.state.arn]
  }

  statement {
    sid       = "StateObjetos"
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = ["${aws_s3_bucket.state.arn}/*"]
  }

  # Leitura dos backups (resumos da pipeline); a escrita é feita pela VM do banco
  statement {
    sid       = "BackupsListar"
    actions   = ["s3:ListBucket", "s3:GetBucketLocation"]
    resources = [aws_s3_bucket.backups.arn]
  }
}

resource "aws_iam_role_policy" "pipeline" {
  name   = "${var.project}-pipeline"
  role   = aws_iam_role.github_actions.id
  policy = data.aws_iam_policy_document.pipeline.json
}
