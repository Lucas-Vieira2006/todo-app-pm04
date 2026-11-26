#!/usr/bin/env bash
# Cria os dois alvos de teste (Ubuntu 24.04 com systemd) e o "volume EBS" simulado do banco.
# Pré-requisito: imagem local/ubuntu-noble-systemd:test gerada por debootstrap (ver README.md desta pasta).
set -euo pipefail
for n in app db; do
  docker rm -f "pm04-$n" >/dev/null 2>&1 || true
  docker volume rm "pm04-$n-docker" "pm04-$n-containerd" >/dev/null 2>&1 || true
  docker run -d --name "pm04-$n" --hostname "pm04-$n" --privileged --cgroupns=host \
    -v /sys/fs/cgroup:/sys/fs/cgroup:rw -v "pm04-$n-docker:/var/lib/docker" -v "pm04-$n-containerd:/var/lib/containerd" \
    --tmpfs /run --tmpfs /run/lock local/ubuntu-noble-systemd:test >/dev/null
done
sleep 5
# Imagem nova: índice do apt vazio (como em uma VM recém-criada)
for n in app db; do docker exec "pm04-$n" sh -c 'rm -rf /var/lib/apt/lists/* && mkdir -p /var/lib/apt/lists/partial'; done
# Disco de dados: arquivo de 1 GiB em loop device, com o mesmo link /dev/disk/by-id usado pelo EBS NVMe
losetup -D 2>/dev/null || true
rm -f /tmp/pm04-ebs.img && truncate -s 1G /tmp/pm04-ebs.img
loop="$(losetup -f --show /tmp/pm04-ebs.img)"
docker exec pm04-db sh -c "mkdir -p /dev/disk/by-id && ln -sf $loop /dev/disk/by-id/nvme-Amazon_Elastic_Block_Store_vol0abc123teste"
echo "Alvos prontos: pm04-app, pm04-db (disco de dados $loop)"
