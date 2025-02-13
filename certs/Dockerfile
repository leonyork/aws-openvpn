ARG ALPINE_VERSION=3.11.5
FROM alpine:${ALPINE_VERSION}

RUN apk add easy-rsa && ln -s /usr/share/easy-rsa/easyrsa /usr/bin/easyrsa

WORKDIR /root/certs

ENTRYPOINT [ "easyrsa" ]
CMD [ "help" ] 