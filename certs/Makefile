ALPINE_VERSION=3.17.0

ALPINE=docker run -v $(CURDIR):/root -w /root alpine:$(ALPINE_VERSION)
DOCKER_COMPOSE=docker-compose
EASYRSA=$(DOCKER_COMPOSE) run easyrsa
EASYRSA_SH=$(DOCKER_COMPOSE) run --entrypoint sh easyrsa

# Help on how to use easyrsa
.PHONY: help
help: .make/.build
	$(EASYRSA) help

build/openssl-easyrsa.cnf: .make/.build
	$(EASYRSA_SH) -c 'cp /usr/share/easy-rsa/openssl-easyrsa.cnf ./'

build/x509-types: .make/.build
	$(EASYRSA_SH) -c 'cp -rf /usr/share/easy-rsa/x509-types ./'

# Init the PKI
.PRECIOUS: .make/.pki
.make/.pki: .make/.build
	$(EASYRSA_SH) -c 'mkdir -p pki/private pki/reqs && dd if=/dev/urandom of=pki/.rnd bs=256 count=1'
	@touch $@

# Build a CA
.PRECIOUS: build/pki/ca.crt
build/pki/ca.crt: build/openssl-easyrsa.cnf .make/.pki
	$(EASYRSA) --batch build-ca nopass

# Build a key
.PRECIOUS: build/pki/private/%.key
build/pki/private/%.key: 
	$(EASYRSA) --batch gen-req $* nopass

# Sign the keys to get a certificate
.PRECIOUS: build/pki/issued/%server.crt
build/pki/issued/%server.crt: build/pki/private/%server.key build/x509-types
	$(EASYRSA) --batch sign-req server $*server

# Sign the keys to get a certificate
.PRECIOUS: build/pki/issued/%client.crt
build/pki/issued/%client.crt: build/pki/private/%client.key build/x509-types
	$(EASYRSA) --batch sign-req client $*client

# Get help on a particular command - e.g. make help-build-ca
.PHONY: sh
sh: build/openssl-easyrsa.cnf build/x509-types
	$(EASYRSA_SH)

# Runs the build and creates a .make/.build file so that we have a timestamp for when we last ran the build
.make/.build: .make/.init Dockerfile docker-compose.yml
	$(DOCKER_COMPOSE) build --build-arg ALPINE_VERSION=$(ALPINE_VERSION) 
	@touch $@

# Where we'll store the status of our build
.make/.init:
	mkdir .make
	@touch .make/.init

.PHONY: clean
clean:
	$(ALPINE) rm -rf .make build