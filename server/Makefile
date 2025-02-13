export IMAGE_NAME=$(IMAGE_NAME)
export PORT=$(PORT)
export PROTOCOL=$(PROTOCOL)

export ALPINE_VERSION=3.17.0
ALPINE=docker run --rm -v $(CURDIR):/root -w /root alpine:$(ALPINE_VERSION)

DOCKER_COMPOSE=docker-compose


.PHONY: push
push: .make/.build
	$(DOCKER_COMPOSE) push

certs/tc.key: .make/.build
	$(DOCKER_COMPOSE) run vpn openvpn --genkey --secret /certs/tc.key

.make/.build: .make/.init Dockerfile docker-compose.yml start.sh
	$(DOCKER_COMPOSE) build --build-arg ALPINE_VERSION=$(ALPINE_VERSION)
	@touch .make/.build

.PHONY: up
up: .make/.build certs/ca.crt certs/server.crt certs/server.key certs/tc.key
	$(DOCKER_COMPOSE) up --force-recreate

.PHONY: pull
pull:
	$(DOCKER_COMPOSE) pull

.make/.init:
	mkdir .make
	@touch .make/.init

clean:
	$(ALPINE) rm -rf .make certs
	$(DOCKER_COMPOSE) down -v --rmi all


