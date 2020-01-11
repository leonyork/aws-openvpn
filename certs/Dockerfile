ARG ALPINE_VERSION
FROM alpine:${ALPINE_VERSION}

RUN apk add easy-rsa && ln -s /usr/share/easy-rsa/easyrsa /usr/bin/easyrsa

WORKDIR /root/certs

ENTRYPOINT [ "easyrsa" ]
CMD [ "help" ] 