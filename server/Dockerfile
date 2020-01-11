ARG ALPINE_VERSION
FROM alpine:${ALPINE_VERSION}

RUN apk add --no-cache openssl openvpn && \
    echo 'net.ipv4.ip_forward=1' > /etc/sysctl.d/30-openvpn-forward.conf && \
    mkdir -p /etc/openvpn/server && \
    openssl dhparam -out /etc/openvpn/server/dh.pem 2048

# Hardening (gets run once we've configured the container)
ADD https://gist.githubusercontent.com/kost/017e95aa24f454f77a37/raw/6581d2a1194492e4d84d55b9004a6eda48c9c478/harden.sh /harden.sh
# No login_duo, or github and remove wget as part of hardening
RUN sed -i -r '/login_duo/ d' harden.sh && \
    sed -i -r '/github/ d' harden.sh && \
    rm -f /usr/bin/wget

COPY start.sh /

CMD [ "sh", "/start.sh" ]