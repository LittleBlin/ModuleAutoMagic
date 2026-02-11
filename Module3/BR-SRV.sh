#!/bin/bash

# IP Addresses
hqsrvip="192.168.1.10"

echo "[INF] Updating apt"
apt-get update
echo "[INF] Installing dependencies"
apt-get install -y rsyslog prometheus-node_exporter

echo "[INF] Mounting CD-ROM sr0"
mount /dev/sr0 /mnt
echo "[INF] Importing user list"
lefile="/mnt/Users.csv"

awk -F ';' 'NR>1 {print $5}' "$lefile" | sort | uniq | while read ou;
do
samba-tool ou add OU="$ou",DC=au-team,DC=irpo;
done

while IFS=";" read -r firstName lastName role phone ou street zip city country password;
do
if [ "$firstName" == "First Name" ];
then
continue
fi
username="${firstName,,}.${lastName,,}"

samba-tool user add "$username" P@ssw0rd --given-name="$firstName" --surname="$lastName" --telephone-number="$phone" --job-title="$role" --userou="OU=$ou"
samba-tool user setexpiry "$username" --noexpiry
done < "$lefile"

echo "[INF] Setting up rsyslog"
sed -i 's/#module(load="imjournal")/module(load="imjournal")/g' /etc/rsyslog.d/00_common.conf
sed -i 's/#module(load="imuxsock")/module(load="imuxsock")/g' /etc/rsyslog.d/00_common.conf
echo -e "ForwardToSyslog=yes\nMaxLevelSyslog=warning" >> /etc/systemd/journald.conf
echo '*.warn @'$hqsrvip > /etc/rsyslog.d/10_to_server.conf
systemctl enable --now rsyslog

echo "[INF] Enable prometheus"
systemctl enable --now prometheus-node_exporter

echo "[INF] Setting up ansible"
cp /mnt/playbook/get_hostname_address.yml /etc/ansible/
cd /etc/ansible/
mkdir PC-INFO
cat << "EOF" > 	get_hostname_address.yml
- name: "Get data from hosts"
  gather_facts: true
  hosts:
    - HQ-SRV
    - HQ-CLI
  tasks:
    - name: "Creating a data file" 
      copy:
        dest: /etc/ansible/PC-INFO/{{ ansible_hostname }}.yml
        content: |
          Hostname: {{ ansible_hostname }}
          IP_Address: {{ ansible_default_ipv4.address }}
      delegate_to: localhost
EOF
ansible-playbook --syntax-check get_hostname_address.yml
ansible-playbook get_hostname_address.yml
cat PC-INFO/hq-cli.yml

echo "[INF] Setting up DNS samba"
samba-tool dns add br-srv.au-team.irpo au-team.irpo mon CNAME hq-srv.au-team.irpo -U Administrator
samba-tool dns query br-srv.au-team.irpo au-team.irpo mon CNAME -U administrator

echo "[WARN] If css styling is lost after certificate, connect to docker image and replace one line"
echo "To enter docker image: docker exec -it testapp ash"

echo "[DONE] Delo Sdelano"