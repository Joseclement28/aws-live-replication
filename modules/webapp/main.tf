
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
    exec > /var/log/user-data.log 2>&1
    set -x

    # Update system
    apt update -y

    # Install Java
    apt install -y openjdk-11-jdk wget

    # Create tomcat user
    useradd -m -U -d /opt/tomcat -s /bin/false tomcat

    # Download Tomcat
    cd /tmp
    wget https://archive.apache.org/dist/tomcat/tomcat-9/v9.0.89/bin/apache-tomcat-9.0.89.tar.gz

    # Install Tomcat
    mkdir -p /opt/tomcat
    tar -xzf apache-tomcat-9.0.89.tar.gz -C /opt/tomcat --strip-components=1

    # Permissions
    chown -R tomcat:tomcat /opt/tomcat
    chmod +x /opt/tomcat/bin/*.sh

    # Create systemd service
    cat <<EOT > /etc/systemd/system/tomcat.service
    [Unit]
    Description=Apache Tomcat
    After=network.target

    [Service]
    Type=forking
    User=tomcat
    Group=tomcat
    Environment="JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64"
    Environment="CATALINA_PID=/opt/tomcat/temp/tomcat.pid"
    Environment="CATALINA_HOME=/opt/tomcat"
    Environment="CATALINA_BASE=/opt/tomcat"
    ExecStart=/opt/tomcat/bin/startup.sh
    ExecStop=/opt/tomcat/bin/shutdown.sh
    Restart=always

    [Install]
    WantedBy=multi-user.target
    EOT

# Reload and start Tomcat
systemctl daemon-reexec
systemctl daemon-reload
systemctl enable tomcat
systemctl start tomcat

# Install MySQL
apt install -y mysql-server
systemctl enable mysql
systemctl start mysql
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
