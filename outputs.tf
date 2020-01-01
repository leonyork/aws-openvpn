output "public_ip" {
  value = "${aws_instance.instance.public_ip}"
}
output "ssh_user" {
  value = "${var.ssh_user}"
}
output "ssh_add_to_known_hosts" {
  value = "ssh-keyscan -H ${aws_instance.instance.public_ip} 2>/dev/null >> ~/.ssh/known_hosts"
}
output "ssh_connect_command" {
  value = "ssh ${var.ssh_user}@${aws_instance.instance.public_ip}"
}
output "vpn_port" {
  value = "${var.vpn_port}"
}