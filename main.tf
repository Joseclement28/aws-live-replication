
provider "aws" {
  region = "ap-south-1"
}

module "webapp" {
  source = "./modules/webapp"

  vpc_name      = "bhavish"
  vpc_cidr      = "192.168.0.0/16"
  subnet_cidr   = "192.168.10.0/24"

  instance_name = "ec2-1"
  ami_id        = "ami-0f5ee92e2d63afc18"
  instance_type = "t3.micro"
  key_name      = "free-account"
  private_ip    = "192.168.10.100"

  ebs_size      = 500
}
