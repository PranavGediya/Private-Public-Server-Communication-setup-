output "vpc_id" {
  value = aws_vpc.main.id
}

output "public_subnet_ids" {
  value = { for k, s in aws_subnet.public : k => s.id }
}

output "private_subnet_ids" {
  value = { for k, s in aws_subnet.private : k => s.id }
}

output "nat_gateway_public_ip" {
  value = aws_eip.nat.public_ip
}

output "public_server_ips" {
  value = {
    PublicS1 = aws_instance.server["PublicS1"].public_ip
    PublicS2 = aws_instance.server["PublicS2"].public_ip
  }
}

output "private_server_ip" {
  value = aws_instance.server["PrivateS3"].private_ip
}

output "ssh_commands" {
  description = "Change ec2-user if your AMI uses a different default user"
  value = {
    PublicS1 = "ssh -i keys/PublicS1-key.pem ec2-user@${aws_instance.server["PublicS1"].public_ip}"
    PublicS2 = "ssh -i keys/PublicS2-key.pem ec2-user@${aws_instance.server["PublicS2"].public_ip}"
  }
}
