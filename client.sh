#!/usr/bin/env sh
{
echo "client
dev tun
proto $SERVER_PROTOCOL
remote $HOST $SERVER_PORT
resolv-retry infinite
nobind
persist-key
persist-tun
remote-cert-tls server
auth SHA512
cipher AES-256-CBC
ignore-unknown-option block-outside-dns
block-outside-dns
verb 3" 
echo "<ca>"
cat certs/build/pki/ca.crt
echo "</ca>"
echo "<cert>"
sed -ne '/BEGIN CERTIFICATE/,$ p' certs/build/pki/issued/"$1"-client.crt
echo "</cert>"
echo "<key>"
cat certs/build/pki/private/"$1"-client.key
echo "</key>"
echo "<tls-crypt>"
sed -ne '/BEGIN OpenVPN Static key/,$ p' server/certs/tc.key
echo "</tls-crypt>"
} > ~/"$1".ovpn