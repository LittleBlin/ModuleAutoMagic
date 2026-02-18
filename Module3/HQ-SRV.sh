#!/bin/bash

# IP Addresses
ispip="172.16.1.1"
hqcliip="192.168.200.2"

echo "[INF] Updating apt"
apt-get update
echo "[INF] Installing dependencies"
apt-get install -y openssl-gost-engine cups cups-pdf logrotate rsyslogd prometheus grafana prometheus-node_exporter fail2ban python3-module-systemd sshpass
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
sshpass -p toor scp web.au-team.irpo.key root@$ispip:~/
sshpass -p toor scp web.au-team.irpo.cer root@$ispip:~/
sshpass -p toor scp docker.au-team.irpo.key root@$ispip:~/
sshpass -p toor scp docker.au-team.irpo.cer root@$ispip:~/
echo "[WARN] Continue on ISP and return after."
echo "[INF] Copyinf certificate to HQ-CLI"
read -p "Press enter to continue..."
scp ca.cer user@$hqcliip:~/

echo "[INF] Setting up rsyslog"
sed -i 's/#module(load="imjournal")/module(load="imjournal")/g' /etc/rsyslog.d/00_common.conf
sed -i 's/#module(load="imuxsock")/module(load="imuxsock")/g' /etc/rsyslog.d/00_common.conf
echo -e "ForwardToSyslog=yes\nMaxLevelSyslog=warning" >> /etc/systemd/journald.conf
cat << "EOF" > /etc/rsyslog.d/91_template.conf
$template DynFile,"/opt/%HOSTNAME%/%PROGRAMNAME%.log" 
*.*       ?DynFile 
&         stop
EOF
systemctl restart rsyslogd
sed -i 's/module(load="imuxsock")/#module(load="imuxsock")/g' /etc/rsyslog.d/10_classic.conf 
logger -p local2.warning "Syslog test message cuz why not"

echo "[INF] Setting up logrotate"
cat << EOF > /etc/logrotate.d/rsyslog
/opt/**/*.log
{ 
weekly
missingok
notifempty 
compress 
minsize 10M
} 
EOF
logrotate -d /etc/logrotate.d/rsyslog
crontab -l | { cat; echo "0 0 * * 0 root /usr/sbin/logrotate /etc/logrotate.d/rsyslog"; } | crontab -

echo "[INF] Setting up prometheus"
# TODO: Dont replace the whole file and just whats needed
# TODO: Use variables for ip
cat << EOF > /etc/prometheus/prometheus.yml
# Sample config for Prometheus.

global:
  scrape_interval:     15s # Set the scrape interval to every 15 seconds. Default is every 1 minute.
  evaluation_interval: 15s # Evaluate rules every 15 seconds. The default is every 1 minute.
  # scrape_timeout is set to the global default (10s).

  # Attach these labels to any time series or alerts when communicating with
  # external systems (federation, remote storage, Alertmanager).
  external_labels:
      monitor: 'example'

# Alertmanager configuration
alerting:
  alertmanagers:
  - static_configs:
    - targets: ['localhost:9093']

# Load rules once and periodically evaluate them according to the global 'evaluation_interval'.
rule_files:
  # - "first_rules.yml"
  # - "second_rules.yml"

# A scrape configuration containing exactly one endpoint to scrape:
# Here it's Prometheus itself.
scrape_configs:
  # The job name is added as a label `job=<job_name>` to any timeseries scraped from this config.
  - job_name: 'prometheus'

    # Override the global default and scrape targets from this job every 5 seconds.
    scrape_interval: 5s
    scrape_timeout: 5s

    # metrics_path defaults to '/metrics'
    # scheme defaults to 'http'.

    static_configs:
      - targets: ['localhost:9090']
  - job_name: hq-srv
    static_configs:
      - targets: ['192.168.1.10:9100']
  - job_name: br-srv
    static_configs:
      - targets: ['192.168.3.10:9100']

  - job_name: node
    # If prometheus-node-exporter is installed, grab stats about the local
    # machine by default.
    static_configs:
      - targets: ['localhost:9100']
EOF

systemctl enable --now prometheus-node_exporter 
systemctl enable --now prometheus
systemctl enable --now grafana-server 

echo "[INF] Setting up fail2ban"
sed -i 's/before = paths-altlinux.conf/before = paths-altlinux-systemd.conf/' /etc/fail2ban/jail.conf
cat << EOF > /etc/fail2ban/jail.d/sshd.conf
[sshd]
enabled = true
port = 2026
filter = sshd
backend = systemd
maxretry = 3
bantime = 1m
EOF
systemctl enable --now fail2ban
fail2ban-client status sshd

# TODO: Make script for cyberbackup
#
#---------Резервное копирование/CyberBackup------------ 
#---HQ-SRV
#vim /etc/fstab
#
#apt-get update && apt-get install kernel-source-6.1 kernel-headers-modules-un-def gcc make kmod-sign -y
#update-kernel
#reboot
#uname -r
#создать пользователя irpoadmin/P@ssw0rd
#
#
#ls -l /lib/modules/6.1.159-un-def-alt1/build
#mount /dev/sr0 /mnt
#bash /mnt/cyberbackup_17.4.36200.x86_64
#[*] Management Server          -
#[*] Agent for Linux            0
#[ ] Bootable Media Builder     a
#[ ] Agent for CommuniGate Pro  a
#[*] Agent for MySQL/MariaDB    a  
#
#
#ss -ltnp | grep 9877
#
#---HQ-CLI
#apt-get update && apt-get install kernel-source-6.1 kernel-headers-modules-un-def gcc make kmod-sign -y
#update-kernel
#reboot
#uname -r
#
#mount /dev/sr0 /mnt
#bash /mnt/cyberbackup_17.4.36200.x86_64
#[ ] Management Server          -
#[*] Agent for Linux            0
#[ ] Bootable Media Builder     a
# -----
#[*] Storage Node               a   
#
#подлючаемся к серверу по IP
#
#В графике:
#1 Создать организацию irpo 
#2 Создать хранилице на узле хранения
#3 Создать планы хранения
#
#control mysqld server
#systemctl restart mysqld


echo "[DONE] Delo Sdelano"
