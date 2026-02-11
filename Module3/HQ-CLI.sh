#!/bin/bash

# IP Addresses
ispip="172.16.1.1"
hqcliip="192.168.200.2"

echo "[INF] Updating apt"
apt-get update
echo "[INF] Installing dependencies"
apt-get install -y cryptopro-preinstall

echo "[INF] Installing certificates"
cp /home/user/ca.cer /etc/pki/ca-trust/source/anchors/
update-ca-trust

echo "[WARN] Here be dragons!"
echo "Sadly, I cant automize installing of cryptopro. Install it yourself."
echo "https://cryptopro.ru/products/csp"
echo "In install_gui.sh select import core certificates from OS"
echo "[DONE] Delo Sdelano"