
# VPC
resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = var.vpc_name
  }
}

# Internet Gateway
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
}

# Public Subnet
resource "aws_subnet" "this" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.subnet_cidr
  map_public_ip_on_launch = true
}

# Route Table
resource "aws_route_table" "this" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }
}

resource "aws_route_table_association" "this" {
  subnet_id      = aws_subnet.this.id
  route_table_id = aws_route_table.this.id
}

# Security Group
resource "aws_security_group" "this" {
  name   = "web-app"
  vpc_id = aws_vpc.this.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "web-app"
  }
}

# EC2 Instance (Tomcat + MySQL)
resource "aws_instance" "this" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.this.id
  private_ip                  = var.private_ip
  key_name                    = var.key_name
  vpc_security_group_ids       = [aws_security_group.this.id]
  associate_public_ip_address = true

  user_data = <<-EOF
              #!/bin/bash
              set -euxo pipefail
              exec > /var/log/user-data.log 2>&1

              sleep 30

              apt update -y

              apt install -y openjdk-17-jdk tomcat10 tomcat10-admin mysql-server

              systemctl start tomcat10
              systemctl enable tomcat10

              systemctl start mysql
              systemctl enable mysql
              EOF

  tags = {
    Name = var.instance_name
  }
}

# 500GB EBS
resource "aws_ebs_volume" "this" {
  availability_zone = aws_instance.this.availability_zone
  size              = var.ebs_size
  type              = "gp3"
}

resource "aws_volume_attachment" "this" {
  device_name = "/dev/xvdf"
  volume_id   = aws_ebs_volume.this.id
  instance_id = aws_instance.this.id
}
