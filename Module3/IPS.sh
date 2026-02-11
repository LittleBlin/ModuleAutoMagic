#!/bin/bash

# IP Addresses
hqsrvip="192.168.1.10"

sed -i 's/#PermitRootLogin without-password/PermitRootLogin yes/g' /etc/openssh/sshd_config
systemctl restart sshd
echo "[WARN] Continue on HQ-SRV.sh and return after"
read -p "Press enter to continue..."

echo "[INF] Updating apt"
apt-get update
echo "[INF] Installing dependencies"
apt-get install -y openssl-gost-engine
control openssl-gost enabled

echo "[INF] Setting up certificates on nginx"
mkdir /etc/nginx/ssl
cp *.au-team.irpo.* /etc/nginx/ssl
# TODO: Dont replace the whole file and just whats needed
cat << "EOF" > 	/etc/nginx/sites-available.d/default.conf
#load_module modules/ngx_http_geoip_module.so;
#load_module modules/ngx_http_perl_module.so;
#load_module modules/ngx_mail_module.so;
#load_module modules/ngx_stream_module.so;

server {
        listen 443 ssl;
        server_name web.au-team.irpo;
        ssl_certificate /etc/nginx/ssl/web.au-team.irpo.cer;
        ssl_certificate_key /etc/nginx/ssl/web.au-team.irpo.key;
        ssl_ciphers GOST2021-GOST8912-GIST8912:HIGH:MEDIUM;
        ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
        ssl_prefer_server_ciphers on;

        location / {
            proxy_pass http://172.16.2.10:8080;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            auth_basic "Restricted Area";
            auth_basic_user_file /etc/nginx/.htpasswd;
        }
}
server {
        listen 443 ssl;
        server_name docker.au-team.irpo;
        ssl_certificate /etc/nginx/ssl/docker.au-team.irpo.cer;
        ssl_certificate_key /etc/nginx/ssl/docker.au-team.irpo.key;
        ssl_ciphers GOST2021-GOST8912-GIST8912:HIGH:MEDIUM;
        ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
        ssl_prefer_server_ciphers on;

        location / {
            proxy_pass http://172.16.1.10:8080;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }

#               charset         on;
#               source_charset  koi8-r;

                access_log  /var/log/nginx/access.log;
}
EOF
systemctl restart nginx
echo "[WARN] Continue on HQ-SRV."