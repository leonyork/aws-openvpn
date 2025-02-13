ALPINE_VERSION=3.11.3
CURL_IMAGE=curlimages/curl:7.68.0
CHECK_IP_URL=http://checkip.amazonaws.com/

SERVER_PORT=1194
SERVER_PROTOCOL=udp

export SERVER_PORT
export SERVER_PROTOCOL

SERVER_IMAGE_VERSION=0.0.5
SERVER_IMAGE_NAME=leonyork/openvpn:${SERVER_IMAGE_VERSION}

MAKE_CERTS=make -C certs
MAKE_SERVER=make PORT=$(SERVER_PORT) PROTOCOL=$(SERVER_PROTOCOL) IMAGE_NAME=$(SERVER_IMAGE_NAME) -C server

ALPINE=docker run --rm -v $(CURDIR):/root -w /root -e HOST=$(HOST) -e SERVER_PORT=$(SERVER_PORT) -e SERVER_PROTOCOL=$(SERVER_PROTOCOL) alpine:$(ALPINE_VERSION)

DOCKER_COMPOSE_INFRA=docker compose -f infra.docker-compose.yml
DOCKER_COMPOSE_CONNECT=docker compose
DOCKER_COMPOSE_TEST=docker compose -f client.docker-compose.yml

CURL=docker run --rm $(CURL_IMAGE)

INFRA=$(DOCKER_COMPOSE_INFRA) -p instance-infra run -e SERVER_PORT=$(SERVER_PORT) -e SERVER_PROTOCOL=$(SERVER_PROTOCOL) 
INFRA_DEPLOYMENT_OUTPUT=$(INFRA) --entrypoint 'terraform output' deploy

CONNECT=$(DOCKER_COMPOSE_CONNECT) -p instance-connect run ssh

SSH_ADD_TO_KNOWN_HOSTS_COMMAND=$(shell $(INFRA_DEPLOYMENT_OUTPUT) ssh_add_to_known_hosts)
SSH_CONNECT_COMMAND=$(shell $(INFRA_DEPLOYMENT_OUTPUT) ssh_connect_command)
SSH_CONNECT_ADDRESS=$(shell $(INFRA_DEPLOYMENT_OUTPUT) ssh_user)@$(shell $(INFRA_DEPLOYMENT_OUTPUT) public_ip)
HOST=$(shell $(INFRA_DEPLOYMENT_OUTPUT) public_ip)
export HOST
PRIVATE_IP=$(shell $(INFRA_DEPLOYMENT_OUTPUT) private_ip)
VPN_PORT=$(shell $(INFRA_DEPLOYMENT_OUTPUT) vpn_port)
MY_IP=$(shell $(CURL) -s $(CHECK_IP_URL))
ACCESS_CIDR=$(MY_IP)/32
TEST=$(DOCKER_COMPOSE_TEST) run vpn

export AWS_ACCESS_KEY_ID
export AWS_SECRET_ACCESS_KEY
export AWS_SESSION_TOKEN

# Deploys the infrastructure and the application (including building the application). This also includes all tests.
# Keep this as the top so that running 'make' does the whole deploy.
.PHONY: deploy
deploy: infra-deploy

# Shortcut to destroy everything (i.e. the infrastructure)
.PHONY: destroy
destroy: infra-destroy

.PHONY: pull-curl
pull-curl:
	docker pull $(CURL_IMAGE)

# Pull the Docker images required for infra
.PHONY: infra-pull
infra-pull:
	@$(DOCKER_COMPOSE_INFRA) pull --quiet

# Pull the Docker images required for infra
.PHONY: connect-build
connect-build:
	@$(DOCKER_COMPOSE_CONNECT) build

# Install all the dependencies - i.e. pull all images required and build all images. TODO: Also get gradle dependencies
.PHONY: install-dependencies
install-dependencies: pull-curl infra-pull connect-build;

# Deploy to AWS
.PHONY: infra-deploy
infra-deploy: infra-pull pull-curl
	$(INFRA) deploy apply -input=false -auto-approve -var "ssh_access_cidr=$(ACCESS_CIDR)"

.PHONY: infra-tf-up
infra-tf-up: infra-pull pull-curl
	$(INFRA) deploy apply -input=false -auto-approve -var "ssh_access_cidr=$(ACCESS_CIDR)"

# Remove all the resources created by deploying the infrastructure
.PHONY: infra-destroy
infra-destroy: infra-pull
	$(INFRA) deploy destroy -input=false -auto-approve -var "ssh_access_cidr=$(ACCESS_CIDR)"

# sh into the container - useful for running commands like import or plan
.PHONY: infra-deploy-sh
infra-deploy-sh: infra-pull  
	$(INFRA) --entrypoint /bin/sh deploy

# Validate the terraform files required for infra
.PHONY: infra-validate
infra-validate: infra-pull
	$(INFRA) --entrypoint /bin/sh deploy -c 'terraform init -input=false -backend=false && terraform validate' 

# Get the outputs from the infra deployment (e.g. make .infra-host gets the host)
.PHONY: infra-%
infra-%: infra-pull
	@$(INFRA_DEPLOYMENT_OUTPUT) $*

.PHONY: infra-deploy-wait
infra-deploy-wait: connect-build
	@echo Waiting for $(HOST):22 to become available...
	@$(CONNECT) sh -c 'while ! nc -z $(HOST) 22; do sleep 1; done; echo $(HOST):22 available'
	@echo Waiting for ssh login to succeed...
	@$(CONNECT) sh -c '$(SSH_ADD_TO_KNOWN_HOSTS_COMMAND); while ! $(SSH_CONNECT_COMMAND) exit; do sleep 1; done; echo ssh login succeeded'

.PHONY: connect
connect: infra-pull connect-build
	$(CONNECT) sh -c "$(SSH_ADD_TO_KNOWN_HOSTS_COMMAND) && $(SSH_CONNECT_COMMAND)"

# Configure the server
.PHONY: install
install: infra-pull connect-build server/certs/server.crt server/certs/server.key server/certs/ca.crt server/certs/tc.key server/docker-compose.yml
	echo '$(CONNECT) sh -c "$(SSH_ADD_TO_KNOWN_HOSTS_COMMAND) && scp -r server/certs $(SSH_CONNECT_ADDRESS):~/ && scp -r server/docker-compose.yml $(SSH_CONNECT_ADDRESS):~/"'
	echo '$(CONNECT) sh -c "$(SSH_ADD_TO_KNOWN_HOSTS_COMMAND) && $(SSH_CONNECT_COMMAND) IMAGE_NAME=$(SERVER_IMAGE_NAME) PROTOCOL=$(SERVER_PROTOCOL) PORT=$(SERVER_PORT) docker composepull"'
	echo '$(CONNECT) sh -c "$(SSH_ADD_TO_KNOWN_HOSTS_COMMAND) && $(SSH_CONNECT_COMMAND) IMAGE_NAME=$(SERVER_IMAGE_NAME) PROTOCOL=$(SERVER_PROTOCOL) PORT=$(SERVER_PORT) docker composeup -d --force-recreate"'

.PRECIOUS: certs/build/pki/ca.crt
certs/build/pki/ca.crt:
	$(MAKE_CERTS) build/pki/ca.crt

.PRECIOUS: certs/build/pki/private/%.key
certs/build/pki/private/%.key:
	$(MAKE_CERTS) build/pki/private/$*.key

.PRECIOUS: certs/build/pki/issued/%.crt
certs/build/pki/issued/%.crt:
	$(MAKE_CERTS) build/pki/issued/$*.crt

# Get the configuration from the server and save it to a file (e.g. make client.ovpn creates the file client.ovpn)
%.ovpn: client.sh server/certs/ca.crt certs/build/pki/private/%-client.key certs/build/pki/issued/%-client.crt server/certs/tc.key
	$(ALPINE) sh client.sh $*

.PRECIOUS: server/certs/tc.key
server/certs/tc.key:
	$(MAKE_SERVER) certs/tc.key

.PRECIOUS: server/certs/server.crt
server/certs/server.crt: certs/build/pki/issued/vpn-server.crt
	$(ALPINE) sh -c "mkdir -p server/certs && cp certs/build/pki/issued/vpn-server.crt $@"

.PRECIOUS: server/certs/server.key
server/certs/server.key: certs/build/pki/private/vpn-server.key
	$(ALPINE) sh -c "mkdir -p server/certs && cp certs/build/pki/private/vpn-server.key $@"

.PRECIOUS: server/certs/ca.crt
server/certs/ca.crt: certs/build/pki/ca.crt
	$(ALPINE) sh -c "mkdir -p server/certs && cp certs/build/pki/ca.crt $@"

.PHONY: server
server: server/certs/server.crt server/certs/server.key server/certs/ca.crt server/certs/tc.key ;

server-up:
	$(MAKE_SERVER) up

server-push:
	$(MAKE_SERVER) push

server-pull:
	$(MAKE_SERVER) pull

# Use a container to try out the configuration - we should be able to hit the aws private ip
test: vpn-client.ovpn
	@echo Waiting for $(HOST):$(SERVER_PORT) to become available...
	@$(CONNECT) sh -c 'while ! nc -u -z $(HOST) $(SERVER_PORT); do sleep 1; done; echo $(HOST):$(SERVER_PORT) available'
	$(TEST) sh -c "openvpn vpn-client.ovpn & while ! nc -w 1 -z $(PRIVATE_IP) 22; do sleep 1; done; echo $(PRIVATE_IP):22 available"

clean:
	docker run --rm -v $(CURDIR):/root -w /root alpine:$(ALPINE_VERSION) rm -f *.ovpn
	$(DOCKER_COMPOSE_CONNECT) down -v --rmi all
	$(DOCKER_COMPOSE_INFRA) down -v --rmi all
	$(DOCKER_COMPOSE_TEST) down -v --rmi all
	$(MAKE_SERVER) clean
	$(MAKE_CERTS) clean
