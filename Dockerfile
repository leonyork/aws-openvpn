ARG ALPINE_VERSION
FROM alpine:${ALPINE_VERSION}

RUN apk add openssh-client ca-certificates