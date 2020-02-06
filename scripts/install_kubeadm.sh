#/bin/bash

until ping -c 1 innovo-cloud.de; do sleep 1; done

export DEBIAN_FRONTEND=noninteractive

name="$1"
domainname="$2"
mydnsname="${name}.${domainname}"

apt-get update && apt-get install  -q -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"  apt-transport-https curl git jq shellinabox nginx certbot python-certbot-nginx
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
cat <<EOF >/etc/apt/sources.list.d/kubernetes.list
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF
apt-get update
apt-get install  -q -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"  kubectl


# configure shellinabox
cat <<EOF> /etc/default/shellinabox
SHELLINABOX_DAEMON_START=1
SHELLINABOX_PORT=4200
SHELLINABOX_ARGS="--no-beep --disable-ssl"
EOF

systemctl restart shellinabox.service

# configure nginx
cat <<EOF> /etc/nginx/upstream.conf 
upstream shellinabox  {
  least_conn;
  server 127.0.0.1:4200 max_fails=3 fail_timeout=60 weight=1;
}
EOF

cat <<EOF> /etc/nginx/nginx.conf 
user www-data;
worker_processes auto;
error_log /var/log/nginx/error.log;
pid /run/nginx.pid;
events {
    worker_connections 1024;
}
http {
    log_format  main  '\$remote_addr - \$remote_user [\$time_local] "\$request" '
                      '\$status \$body_bytes_sent "\$http_referer" '
                      '"\$http_user_agent" "\$http_x_forwarded_for"';
    log_format proxy '[\$time_local] Cache: \$upstream_cache_status '
                     '\$upstream_addr \$upstream_response_time \$status '
                     '\$bytes_sent \$proxy_add_x_forwarded_for \$request_uri';
    access_log  /var/log/nginx/access.log  main;
    sendfile            on;
    tcp_nopush          on;
    tcp_nodelay         on;
    keepalive_timeout   65;
    types_hash_max_size 2048;
    include             /etc/nginx/mime.types;
    default_type        application/octet-stream;
    include /etc/nginx/upstream.conf;
    include /etc/nginx/sites-enabled/*;
}
EOF

## nginx standard config (step one)
cat <<EOF> /etc/nginx/sites-enabled/default 
server {
	listen 80 default_server;
	listen [::]:80 default_server;
	root /var/www/html;
	server_name _;
	location / {
		try_files \$uri \$uri/ =404;
	}
}
EOF

systemctl restart nginx.service

certbot certonly --noninteractive  --agree-tos --register-unsafely-without-email -d ${mydnsname} --nginx

## nginx tls config (step two)
cat <<EOF> /etc/nginx/sites-enabled/${mydnsname}.conf 
server {
	root /var/www/html;
	index index.html index.htm index.nginx-debian.html;
  server_name ${mydnsname}; 
	location / {
    proxy_pass      http://shellinabox;
	}
  listen [::]:443 ssl ipv6only=on; 
  listen 443 ssl; 
  ssl_certificate /etc/letsencrypt/live/${mydnsname}/fullchain.pem; 
  ssl_certificate_key /etc/letsencrypt/live/${mydnsname}/privkey.pem; 
  include /etc/letsencrypt/options-ssl-nginx.conf; 
  ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem; 
}
server {
    if (\$host = ${mydnsname}) {
        return 301 https://\$host\$request_uri;
    } 
	listen 80 ;
	listen [::]:80 ;
  server_name ${mydnsname};
  return 404; 
}

EOF

systemctl restart nginx.service

# build usable user environment
kubectl completion bash > /home/innovo/.kubectlcompletion
echo '. /home/innovo/.kubectlcompletion' >> /home/innovo/.bashrc
