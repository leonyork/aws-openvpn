#!/usr/bin/env sh
CONF=/etc/openvpn/server
IP=`hostname -i`
echo "local $IP
port $PORT
proto $PROTOCOL
dev tun
ca $CA_CERT_LOCATION
cert $SERVER_CERT_LOCATION
key $SERVER_KEY_LOCATION
dh ${CONF}/dh.pem
auth SHA512
tls-crypt $TLS_CRYPT_KEY_LOCATION
topology subnet
server 10.8.0.0 255.255.255.0
ifconfig-pool-persist ipp.txt
push \"redirect-gateway def1 bypass-dhcp\"" > ${CONF}/server.conf

grep -v '#' "/etc/resolv.conf" | grep nameserver | grep -E -o '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | while read line; do
  echo "push \"dhcp-option DNS $line\"" >> ${CONF}/server.conf
done

echo "keepalive 10 120
cipher AES-256-CBC
user openvpn
group openvpn
persist-key
persist-tun
status openvpn-status.log
verb 3
crl-verify crl.pem" >> ${CONF}/server.

if [[ "$PROTOCOL" = "udp" ]]; then
  echo "explicit-exit-notify" >> ${CONF}/server.conf
fi

/sbin/iptables -t nat -A POSTROUTING -s 10.8.0.0/24 ! -d 10.8.0.0/24 -j SNAT --to $IP
/sbin/iptables -I INPUT -p $PROTOCOL --dport $PORT -j ACCEPT 
/sbin/iptables -I FORWARD -s 10.8.0.0/24 -j ACCEPT
/sbin/iptables -I FORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT

# Hardening - move the things we need out of sbin before hardening so they don't get deleted
mv /usr/sbin/openvpn /openvpn.tmp
mv /sbin/ip /ip.tmp
sh /harden.sh > /dev/null 2>&1
mv /openvpn.tmp /usr/sbin/openvpn
mv /ip.tmp /sbin/ip

/usr/sbin/openvpn ${CONF}/server.conf