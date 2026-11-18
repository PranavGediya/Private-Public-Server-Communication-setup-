variable "region" {
  description = "AWS region"
  type        = string
  default     = "eu-north-1"
}

variable "vpc_name" {
  description = "Name tag of the VPC"
  type        = string
  default     = "My-VPC"
}

variable "vpc_cidr" {
  description = "IPv4 CIDR block of the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnets" {
  description = "Public subnets (use the MAIN route table -> IGW)"
  type = map(object({
    cidr = string
    az   = string
  }))
  default = {
    "public-1a" = { cidr = "10.0.1.0/24", az = "eu-north-1a" }
    "public-1b" = { cidr = "10.0.2.0/24", az = "eu-north-1b" }
  }
}

variable "private_subnets" {
  description = "Private subnets (use Private-RT -> NAT)"
  type = map(object({
    cidr = string
    az   = string
  }))
  default = {
    "private-1a" = { cidr = "10.0.3.0/24", az = "eu-north-1a" }
    "private-1b" = { cidr = "10.0.4.0/24", az = "eu-north-1b" }
  }
}

variable "ami_id" {
  description = "AMI used by all 3 instances"
  type        = string
  default     = "ami-0f71b90bee7050a75"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.small"
}

variable "user_data_file" {
  description = "Path to the user data script used by all 3 instances (must be a raw shell script)"
  type        = string
  default     = "userdata.sh"
}
