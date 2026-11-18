#!/bin/bash
# Sample user data - replace with your own script if you prefer.
yum update -y
yum install -y httpd
systemctl enable --now httpd

# Show this instance's subnet ID on the index page (IMDSv2)
TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
MAC=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/mac)
SUBNET_ID=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
  "http://169.254.169.254/latest/meta-data/network/interfaces/macs/$MAC/subnet-id")

echo "<h1>Hello from subnet: $SUBNET_ID</h1>" > /var/www/html/index.html
