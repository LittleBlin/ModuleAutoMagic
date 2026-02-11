#!/bin/bash

# IP Addresses
ispip="172.16.1.1"
hqcliip="192.168.200.2"

echo "[INF] Updating apt"
apt-get update
echo "[INF] Installing dependencies"
apt-get install -y openssl-gost-engine cups cups-pdf logrotate rsyslogd prometheus grafana prometheus-node_exporter fail2ban python3-module-systemd
control openssl-gost enabled

echo "[INF] Setting up certificates and other ssl stuff"
openssl genpkey -algorithm gost2012_256 -pkeyopt paramset:TCB -out ca.key
openssl req -new -x509 -md_gost12_256 -days 30 -key ca.key -subj "/C=RU/O=au-team.irpo/CN=hq-srv.au-team.irpo" -out ca.cer
openssl genpkey -algorithm gost2012_256 -pkeyopt paramset:A -out web.au-team.irpo.key
openssl genpkey -algorithm gost2012_256 -pkeyopt paramset:A -out docker.au-team.irpo.key
openssl req -new  -md_gost12_256 -key web.au-team.irpo.key -subj "/C=RU/O=au-team.irpo/CN=web.au-team.irpo" -out web.au-team.irpo.csr
openssl req -new  -md_gost12_256 -key docker.au-team.irpo.key -subj "/C=RU/O=au-team.irpo/CN=docker.au-team.irpo" -out docker.au-team.irpo.csr
openssl x509 -req -in web.au-team.irpo.csr -CA ca.cer -CAkey ca.key -CAcreateserial -out web.au-team.irpo.cer -days 30
openssl x509 -req -in docker.au-team.irpo.csr -CA ca.cer -CAkey ca.key -CAcreateserial -out docker.au-team.irpo.cer -days 30
echo "[WARN] Launch the ISP.sh script in ISP server before continuing!"
read -p "Press enter to continue..."

echo "[INF] Copying files to ISP"
scp web.au-team.irpo.key root@$ispip:~/
scp web.au-team.irpo.cer root@$ispip:~/
scp docker.au-team.irpo.key root@$ispip:~/
scp docker.au-team.irpo.cer root@$ispip:~/
echo "[WARN] Continue on ISP and return after."
read -p "Press enter to continue..."
scp ca.cer user@$hqcliip:~/

echo "[WARN] Launch HQ-CLI.sh script in HQ-CLI server"
