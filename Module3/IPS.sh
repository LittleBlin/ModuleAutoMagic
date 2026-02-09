#!/bin/bash

sed -i 's/#PermitRootLogin without-password/PermitRootLogin yes/g' /etc/openssh/sshd_config
echo "[WARN] Continue on HQ-SRV.sh and return after"
read -p "Press enter to continue..."