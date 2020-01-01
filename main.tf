provider "aws" {
  region = var.region
  version = "2.43"
}

provider "random" {
  version = "2.2"
}

provider "local" {
  version = "1.4"
} 

data "local_file" "ssh_public_key" {
    filename = var.ssh_public_key_location
}

resource "random_uuid" "security_group_unique_id" { }

resource "aws_security_group" "ssh" {
  name        = "ssh-${random_uuid.security_group_unique_id.result}"
  description = "Allow SSH"
  # Add to the default VPC for now - if required change to be a different VPC
  #vpc_id      = "${aws_vpc.main.id}"

  # SSH
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${var.ssh_access_cidr}"]
  }

  # Allow all access out
  # TODO: Can this be passed in as a variable?
  egress {
    from_port         = 0
    to_port           = 0 #from_port (0) and to_port (65535) must both be 0 to use the 'ALL' "-1" protocol!
    protocol          = "-1"
    cidr_blocks       = ["0.0.0.0/0"]
    ipv6_cidr_blocks  = ["::/0"]
  }
}

data "aws_ami" "ami" {
  filter {
    name   = "name"
    values = [var.ami_name]
  }
  
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }

  owners = [var.ami_owner]
}

resource "aws_instance" "instance" {
  ami           = data.aws_ami.ami.id
  instance_type = var.instance_type
  security_groups = ["${aws_security_group.ssh.name}"]

  lifecycle {
    create_before_destroy = true
  }

  user_data = <<EOF
#!/bin/bash
su ${var.ssh_user} -c 'echo "${data.local_file.ssh_public_key.content}" > ~/.ssh/authorized_keys'
    EOF
}