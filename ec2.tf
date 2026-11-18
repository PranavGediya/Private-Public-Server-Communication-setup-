locals {
  instances = {
    PublicS1 = {
      subnet_id = aws_subnet.public["public-1a"].id
      sg_id     = aws_security_group.public_web.id
    }
    PublicS2 = {
      subnet_id = aws_subnet.public["public-1b"].id
      sg_id     = aws_security_group.public_web.id
    }
    PrivateS3 = {
      subnet_id = aws_subnet.private["private-1b"].id
      sg_id     = aws_security_group.private_app.id
    }
  }
}

# ---------------------------------------------------------------
# 3 key pairs: generated here, registered in AWS,
# private key saved locally in ./keys/<name>-key.pem
# ---------------------------------------------------------------
resource "tls_private_key" "ec2" {
  for_each = local.instances

  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "ec2" {
  for_each = local.instances

  key_name   = "${each.key}-key"
  public_key = tls_private_key.ec2[each.key].public_key_openssh
}

resource "local_file" "private_key" {
  for_each = local.instances

  content         = tls_private_key.ec2[each.key].private_key_pem
  filename        = "${path.module}/keys/${each.key}-key.pem"
  file_permission = "0400"
}

# ---------------------------------------------------------------
# Instances: PublicS1, PublicS2, PrivateS3
# ---------------------------------------------------------------
resource "aws_instance" "server" {
  for_each = local.instances

  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = each.value.subnet_id
  vpc_security_group_ids = [each.value.sg_id]
  key_name               = aws_key_pair.ec2[each.key].key_name

  user_data                   = file("${path.module}/${var.user_data_file}")
  user_data_replace_on_change = true

  tags = {
    Name = each.key
  }

  # Routes must exist before boot, otherwise yum in user data fails
  # (public servers need the IGW route, PrivateS3 needs the NAT route).
  depends_on = [
    aws_default_route_table.main,
    aws_route.private_nat,
    aws_route_table_association.private,
  ]
}
