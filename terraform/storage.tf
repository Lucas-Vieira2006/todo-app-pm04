# Volume de dados do MongoDB separado do disco raiz: sobrevive à troca do tipo
# da VM e à recriação do contêiner. Montado pelo Ansible em /srv/mongo-data.
resource "aws_ebs_volume" "mongo_data" {
  #checkov:skip=CKV_AWS_189:Criptografado com a chave gerenciada pela AWS (sem custo); CMK custaria US$ 1/mês
  availability_zone = local.availability_zone
  size              = var.db_data_volume_size
  type              = "gp3"
  encrypted         = true

  tags = {
    Name = "${local.name_prefix}-mongo-data"
    Role = "db-data"
  }
}

resource "aws_volume_attachment" "mongo_data" {
  device_name = "/dev/sdf"
  volume_id   = aws_ebs_volume.mongo_data.id
  instance_id = aws_instance.db.id
}
