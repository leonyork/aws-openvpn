# Deploy a VPN server

[![Build Status](https://travis-ci.com/leonyork/aws-openvpn.svg?branch=master)](https://travis-ci.com/leonyork/aws-openvpn)

Use [Terraform](https://www.terraform.io/) to create the server.

Assumes that you have a public/private key pair generated in ~/.ssh with the public key name id_rsa.pub. See .travis.yml install section if you need to generate one.

## Infrastructure

You'll need make, docker and docker-compose installed. You'll need an AWS account with the environment variables ```AWS_SECRET_KEY_ID``` and ```AWS_SECRET_ACCESS_KEY``` set.

### Deploy

```make infra-deploy```

### Destroy

```make infra-destroy```

### Connect

Once you've deployed the infrastructure:

```make connect```

### Get the client configuration

Once you've deployed the infrastructure:

```make client.ovpn```