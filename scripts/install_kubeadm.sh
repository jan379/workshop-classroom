#/bin/bash

until ping -c 1 innovo-cloud.de; do sleep 1; done

export DEBIAN_FRONTEND=noninteractive

apt-get update && apt-get install  -q -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"  apt-transport-https curl git jq shellinabox
systemctl enable docker.service
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
cat <<EOF >/etc/apt/sources.list.d/kubernetes.list
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF
apt-get update
apt-get install  -q -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"  kubectl

# enable ssh password access
sed 's/PasswordAuthentication no/PasswordAuthentication yes/g' -i /etc/ssh/sshd_config
systemctl restart sshd.service

sed -i s/4200/443/g /etc/default/shellinabox && systemctl restart shellinabox.service

kubectl completion bash > /home/innovo/.kubectlcompletion

echo '. /home/innovo/.kubectlcompletion' >> /home/innovo/.bashrc
