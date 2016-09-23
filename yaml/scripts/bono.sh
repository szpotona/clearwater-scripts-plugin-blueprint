#!/bin/bash
ctx logger info "In Bono ${public_ip}   ${dns_ip}   "

echo "In Bono ${public_ip}   ${dns_ip}   " > /home/ubuntu/dnsfile

exec > >(sudo tee -a /var/log/clearwater-cloudify.log) 2>&1


# Configure the APT software source.
echo 'deb http://repo.cw-ngv.com/stable binary/' | sudo tee -a /etc/apt/sources.list.d/clearwater.list
curl -L http://repo.cw-ngv.com/repo_key | sudo apt-key add -
sudo apt-get update

# Configure /etc/clearwater/local_config.
sudo mkdir -p /etc/clearwater
etcd_ip=$(ip addr show dev eth0 | grep "inet\b" | awk '{print $2}' | cut -d/ -f1)
cat << EOF | sudo -E tee -a /etc/clearwater/local_config
local_ip=$(ip addr show dev eth0 | grep "inet\b" | awk '{print $2}' | cut -d/ -f1)
public_ip=$public_ip
public_hostname=$public_ip
etcd_cluster=$(ip addr show dev eth0 | grep "inet\b" | awk '{print $2}' | cut -d/ -f1)
EOF

sudo -E bash -c 'cat > /etc/clearwater/shared_config << EOF
# Deployment definitions
home_domain=example.com
sprout_hostname=sprout.example.com
hs_hostname=hs.example.com:8888
hs_provisioning_hostname=hs.example.com:8889
ralf_hostname=ralf.example.com:10888
xdms_hostname=homer.example.com:7888

# Email server configuration
smtp_smarthost=localhost
smtp_username=username
smtp_password=password
email_recovery_sender=clearwater@example.org

# Keys
signup_key=secret
turn_workaround=secret
ellis_api_key=secret
ellis_cookie_key=secret

upstream_hostname=scscf.\$sprout_hostname
upstream_port=5054

EOF'


# Now install the software.
# "-o DPkg::options::=--force-confnew" works around https://github.com/Metaswitch/clearwater-infrastructure/issues/186.
sudo DEBIAN_FRONTEND=noninteractive apt-get install bono --yes --force-yes -o DPkg::options::=--force-confnew
sudo DEBIAN_FRONTEND=noninteractive apt-get install clearwater-config-manager --yes --force-yes
sudo DEBIAN_FRONTEND=noninteractive apt-get install clearwater-snmpd --yes --force-yes

sudo /usr/share/clearwater/clearwater-config-manager/scripts/upload_shared_config
#sudo /usr/share/clearwater/clearwater-config-manager/scripts/apply_shared_config --sync


cat > /home/ubuntu/dnsupdatefile << EOF
server ${dns_ip}
update add bono-0.example.com. 30 A ${public_ip}
update add example.com. 30 A ${public_ip}
update add example.com. 30 NAPTR   1 1 "S" "SIP+D2T" "" _sip._tcp
update add example.com. 30 NAPTR   2 1 "S" "SIP+D2U" "" _sip._udp
update add _sip._tcp.example.com. 30 SRV     0 0 5060 bono-0
update add _sip._udp.example.com. 30 SRV     0 0 5060 bono-0
send
EOF


# Update DNS
retries=0
while ! { sudo -E nsupdate -y "example.com:8r6SIIX/cWE6b0Pe8l2bnc/v5vYbMSYvj+jQPP4bWe+CXzOpojJGrXI7iiustDQdWtBHUpWxweiHDWvLIp6/zw==" -v /home/ubuntu/dnsupdatefile
} && [ $retries -lt 10 ]
do
  retries=$((retries + 1))
  echo 'nsupdate failed - retrying (retry '$retries')...'
  sleep 5
done

