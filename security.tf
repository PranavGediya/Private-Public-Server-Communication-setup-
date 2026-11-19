# ---------------------------------------------------------------
# SG 1: Public Web
# ---------------------------------------------------------------
resource "aws_security_group" "public_web" {
  name        = "Public Web"
  description = "HTTP and SSH from anywhere"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "Public Web"
  }
}

resource "aws_vpc_security_group_ingress_rule" "public_web_http" {
  security_group_id = aws_security_group.public_web.id
  description       = "HTTP"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "public_web_ssh" {
  security_group_id = aws_security_group.public_web.id
  description       = "SSH"
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "public_web_icmp" {
  security_group_id = aws_security_group.public_web.id
  description       = "ICMP"
  ip_protocol       = "icmp"
  from_port         = "-1"
  to_port           = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "public_web_all" {
  security_group_id = aws_security_group.public_web.id
  description       = "All outbound"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

# ---------------------------------------------------------------
# SG 2: Private app (HTTP only from the Public Web SG)
# ---------------------------------------------------------------
resource "aws_security_group" "private_app" {
  name        = "Private app"
  description = "HTTP from Public Web SG"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "Private app"
  }
}

resource "aws_vpc_security_group_ingress_rule" "private_app_http" {
  security_group_id            = aws_security_group.private_app.id
  description                  = "HTTP from Public Web"
  ip_protocol                  = "tcp"
  from_port                    = 80
  to_port                      = 80
  referenced_security_group_id = aws_security_group.public_web.id
}

# Terraform removes the default allow-all egress, so add it back.
# Without it PrivateS3 cannot reach the NAT to run yum in user data.
resource "aws_vpc_security_group_egress_rule" "private_app_all" {
  security_group_id = aws_security_group.private_app.id
  description       = "All outbound (via NAT)"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}
