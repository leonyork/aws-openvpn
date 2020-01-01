CURL_IMAGE=curlimages/curl:7.67.0
CHECK_IP_URL=http://checkip.amazonaws.com/

DOCKER_COMPOSE_INFRA=docker-compose -f infra.docker-compose.yml
DOCKER_COMPOSE_CONNECT=docker-compose

CURL=docker run --rm $(CURL_IMAGE)

INFRA=$(DOCKER_COMPOSE_INFRA) -p instance-infra run
INFRA_DEPLOYMENT_OUTPUT=$(INFRA) --entrypoint 'terraform output' deploy

CONNECT=$(DOCKER_COMPOSE_CONNECT) -p instance-connect run ssh

SSH_ADD_TO_KNOWN_HOSTS_COMMAND=$(shell $(INFRA_DEPLOYMENT_OUTPUT) ssh_add_to_known_hosts)
SSH_CONNECT_COMMAND=$(shell $(INFRA_DEPLOYMENT_OUTPUT) ssh_connect_command)
HOST=$(shell $(INFRA_DEPLOYMENT_OUTPUT) public_ip)
MY_IP=$(shell $(CURL) -s $(CHECK_IP_URL))
ACCESS_CIDR=$(MY_IP)/32

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

# Remove all the resources created by deploying the infrastructure
.PHONY: infra-destroy
infra-destroy: infra-pull
	$(INFRA) deploy destroy -input=false -auto-approve -force -var "ssh_access_cidr=$(ACCESS_CIDR)"

# sh into the container - useful for running commands like import or plan
.PHONY: infra-deploy-sh
infra-deploy-sh: infra-pull  
	$(INFRA) --entrypoint /bin/sh deploy

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

.PHONY: infra-test
infra-test: infra-pull connect-build
	$(CONNECT) sh -c "$(SSH_ADD_TO_KNOWN_HOSTS_COMMAND) && $(SSH_CONNECT_COMMAND) 'echo connected as \$$(whoami)'"

.PHONY: connect
connect: infra-pull connect-build
	$(CONNECT) sh -c "$(SSH_ADD_TO_KNOWN_HOSTS_COMMAND) && $(SSH_CONNECT_COMMAND)"

.PHONY: connect-log
connect-log: connect-build
	$(CONNECT) sh -c "cat ~/.ssh/id_rsa && cat ~/.ssh/id_rsa.pub"