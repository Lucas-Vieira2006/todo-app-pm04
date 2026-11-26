# State remoto no S3 com lock nativo (use_lockfile), criado pela stack terraform/bootstrap.
# Configuração parcial: bucket, key e region são informados no terraform init, por exemplo:
#
#   terraform init \
#     -backend-config="bucket=todo-app-tfstate-<conta>" \
#     -backend-config="key=todo-app/dev/terraform.tfstate" \
#     -backend-config="region=us-east-1"
#
# Assim cada ambiente (dev/homolog/prod) usa uma chave própria no mesmo bucket.
terraform {
  backend "s3" {
    encrypt      = true
    use_lockfile = true
  }
}
