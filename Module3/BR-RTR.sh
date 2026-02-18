#!/bin/bash

# IP Addresses
hqsrvip="192.168.1.10"

read -p "Is it your first time launching this script? (y)Yes/(n)No/(c)Cancel:- " choice

# giving choices there tasks using
case $choice in
[yY]* ) firstinstall ;;
[nN]* ) secondinstall ;;
[cC]* ) echo "Script cancelled" ;;
*) exit ;;
esac

function firstinstall {
echo "[INF] Updating apt"
apt-get update
echo "[INF] Installing dependencies"
apt-get install -y openvpn

echo "[INF] Setting up openvpn"
cat > /etc/openvpn/keys/static.key
chmod og-rw /etc/openvpn/keys/static.key
cat << EOF > /etc/openvpn/client/tun0.conf
remote 172.16.1.10
dev tun0
    cipher AES-256-CBC
    auth-nocache
    ifconfig 192.168.5.2 192.168.5.1
    secret /etc/openvpn/keys/static.key
EOF
systemctl enable openvpn-client@tun0
echo "[INF] The server will reboot when continuing, launch the script again and select [N]"
read -p "Press enter to continue..."
cp /etc/net/ifaces/gre1/ /etc/net/ifaces/gre1.bk/
reboot
}

function secondinstall {
echo "[INF] Finishing setup"
sed -i 's/interface gre1/interface tun0/' /etc/frr/frr.conf ; grep tun0 -A6 /etc/frr/frr.conf
systemctl restart frr

echo "[INF] Setting up rsyslog"
sed -i 's/#module(load="imjournal")/module(load="imjournal")/g' /etc/rsyslog.d/00_common.conf
sed -i 's/#module(load="imuxsock")/module(load="imuxsock")/g' /etc/rsyslog.d/00_common.conf
echo -e "ForwardToSyslog=yes\nMaxLevelSyslog=warning" >> /etc/systemd/journald.conf
echo '*.warn @'$hqsrvip > /etc/rsyslog.d/10_to_server.conf
systemctl enable --now rsyslog

echo "[DONE] Delo Sdelano"

}
