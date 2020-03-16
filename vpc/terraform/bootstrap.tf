# This file is meant to provide the 'networkless' environment, which lives in the 'crash' trust zone.
# See also https://github.com/zinfra/backend-issues/wiki/trust-zone-environments (TODO: move that page over to either the zinfra/backend-wiki's wiki, or to zinfra/backend-wiki's repository)

# the 'offline' environment

# * VPC with access only via SSH through the bastion host.
# * private DNS zone crash.zinfra.io

# To deploy this file, you will need a user with the policies "AmazonEC2FullAccess", "IAMFullAccess", "AmazonS3FullAccess", and "AmazonDynamoDBFullAccess".
# FIXME: drill down on the above.

terraform {
  required_version = ">= 0.12.0"

  backend "s3" {
    encrypt = true
    region  = "eu-central-1"

    # TODO: create IAM policy which only allows access to this bucket under
    # envrionments/crash and to the -crash dynamodb table
    bucket = "z-terraform-remote-state"

    key = "environments/offline/bootstrap"

    dynamodb_table = "z-terraform-state-lock-dynamo-lock-environment-offline"
  }
}

# there is an example here also:
# https://github.com/kubernetes-sigs/kubespray/tree/master/contrib/terraform/aws
# https://github.com/terraform-aws-modules/terraform-aws-vpc/blob/master/examples/complete-vpc/main.tf

# In AWS, (eu-central-1)
provider "aws" {
  region = "eu-central-1"
}

# Used for the in-VPC EC2 endpoint.
data "aws_security_group" "default" {
  name   = "default"
  vpc_id = module.vpc.vpc_id
}

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "offline"

  cidr = "172.17.0.0/20"

  azs             = ["eu-central-1a", "eu-central-1b", "eu-central-1c"]
  private_subnets = ["172.17.0.0/22", "172.17.4.0/22", "172.17.8.0/22"]
  public_subnets  = ["172.17.12.0/24", "172.17.13.0/24", "172.17.14.0/24"]

  enable_dns_hostnames = true
  enable_dns_support   = true

  enable_dhcp_options      = true
  dhcp_options_domain_name = "offline.zinfra.io"
#  dhcp_options_domain_name_servers = 
  
  # In case we run terraform from within the environment.
  # VPC endpoint for DynamoDB
  enable_dynamodb_endpoint = true

  # In case we run terraform from within the environment.
  # VPC Endpoint for EC2
  enable_ec2_endpoint              = true
  ec2_endpoint_private_dns_enabled = true
  ec2_endpoint_security_group_ids  = [data.aws_security_group.default.id]

  enable_nat_gateway = true
  one_nat_gateway_per_az = false
# Use this only in productionish environments.
#  one_nat_gateway_per_az = true

  tags = {
    Owner       = "Backend Team"
    Environment = "Offline"
    TrustZone   = "Crash"
  }
  vpc_tags = {
    Owner       = "Backend Team"
    Name        = "vpc-offline"
    TrustZone   = "Crash"
  }
}

# A SSH key, used during golden image creation. destroyed at the end of the process.
resource "aws_key_pair" "crash-nonprod-deployer-julia" {
  key_name   = "crash-nonprod-deployer-julia"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDNpXSteA3yB1vqNdLnNyHHaDIhVGWtjKhThNa27lc48TRIekwG8byLpy/shaYFtnpJfhjo+3pffxZm26OmB9XHnH3EgWxcu9QSFDha4/JzHdK2yjLaSgQ9dHZWAk6T2s8UuzoqxWEi4RY5WJNfmh30SEiEnUIwLTqlc1lQ1Lypo6OqKmu78f0Tn6lqdhNb8ZaggYnvNJgzZpSTp0zZA4OX7GP4yp9ghWLzWKsH7Lu+zbYm4Yu5dtKVbqK2+FBLKNbY/6HMjU9ujX66XJG/g3qT6ILRThnDdnidtMv4NRLxPM7YkgF85Mfaymke12pU8Oh90TLJF3Lk+J5b2sGZz7DZprsrZCav4/zx1zUy6/hMPti6dWZTktOauBpi33g55AnXyL+HHje8lb7Bp4oH2JpM3YEXxJ3nNeCyIN7DKG+lFhosEk7diUf6VcGxX9+CHmKKeJgZrQJRsjWpCvt4OFN/AAdyqOe9hLS31oJLX0cLEUWtmMOsl3sPwJBD9lCx42QbSR2zet1W0dq0ivJ7czEUuNYqTdK4tRT2qo+b4NOGn4WNgyLjDTX/iGS/ZWNn3FXI8NU2h8GxbCOXJejdiweFp/Sev3Y1hMuTVTBQH3PwXz7rbDPDWT/X7K9HuCkuqzaHh+Vvo7PFgtHcGsn1a4sv8zD4rnXV/sH7sYOSAvLQQQ== julia.longtin@wire.com"
}

# Finding AMIs:
# https://cloud-images.ubuntu.com/locator/ec2/

data "aws_ami" "ubuntu18LTS-ARM64" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-arm64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
  }

data "aws_ami" "ubuntu18LTS-AMD64" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
  }

# Finding Instance types:
# https://www.ec2instances.info/

# point an elastic IP to our bastion host.
resource "aws_eip" "bastion-offline" {
  vpc                       = true
#network_interface         = "${aws_network_interface.bastion-crash-in.id}"
  instance = "${aws_instance.bastion-offline.id}"
}



# A security group for ssh from the outside world. should only be applied to our bastion hosts.
resource "aws_security_group" "world_ssh_in" {
  name        = "world_ssh_in"
  description = "ssh in from the outside world"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    }

  tags = {
    Name = "world_ssh_in"
  }
}

# A security group for access to the outside world over http and https. should only be applied to our bastion host.
resource "aws_security_group" "world_web_out" {
  name        = "world_web_out"
  description = "http/https to the outside world"
  vpc_id      = module.vpc.vpc_id

  egress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    }
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    }

  tags = {
    Name = "world_web_out"
  }
}

# A security group for making ssh connections inside the VPC. should be added to the admin and bastion hosts only.
resource "aws_security_group" "vpc_ssh_from" {
  name        = "vpc_ssh_from"
  description = "hosts that are allowed to ssh into other hosts"
  vpc_id      = module.vpc.vpc_id

  egress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["172.17.0.0/20"]
  }

  tags = {
    Name = "vpc_ssh_from"
  }
}

# A security group for recieving ssh connections inside the VPC. should be added to the admin and bastion hosts only.
resource "aws_security_group" "has_ssh" {
  name        = "has_ssh"
  description = "hosts that should be reachable via SSH."
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    security_groups = ["${aws_security_group.vpc_ssh_from.id}"]
  }

  tags = {
    Name = "has_ssh"
  }
}



# A security group for making dns requests inside the VPC. should be added to the admin, ansible, and kubernetes nodes.
resource "aws_security_group" "vpc_dns_from" {
  name        = "vpc_dns_from"
  description = "hosts that are allowed to perform DNS requests"
  vpc_id      = module.vpc.vpc_id

  egress {
    from_port   = 53
    to_port     = 53
    protocol    = "tcp"
    cidr_blocks = ["172.17.0.0/20"]
  }

  egress {
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = ["172.17.0.0/20"]
  }

  tags = {
    Name = "vpc_dns_from"
  }
}

# A security group for recieving DNS requests inside the VPC. should be added to the assethost only.
resource "aws_security_group" "has_dns" {
  name        = "has_dns"
  description = "hosts that serve DNS."
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 53
    to_port     = 53
    protocol    = "tcp"
    security_groups = ["${aws_security_group.vpc_dns_from.id}"]
  }

  ingress {
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    security_groups = ["${aws_security_group.vpc_dns_from.id}"]
  }

  tags = {
    Name = "has_dns"
  }
}

# A security group for kubernetes nodes. should be added to them only.
resource "aws_security_group" "vpc_k8s_from" {
  name        = "vpc_k8s_from"
  description = "hosts that are allowed to speak to kubernetes."
  vpc_id      = module.vpc.vpc_id

  egress {
    from_port   = 2379
    to_port     = 2380
    protocol    = "tcp"
    cidr_blocks = ["172.17.0.0/20"]
  }

  tags = {
    Name = "vpc_k8s_from"
  }
}

# A security group for kubernetes nodes. should be added to them only.
resource "aws_security_group" "has_k8s" {
  name        = "has_k8s"
  description = "hosts that have kubernetes."
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 2379
    to_port     = 2380
    protocol    = "tcp"
    security_groups = ["${aws_security_group.vpc_k8s_from.id}"]
  }

  tags = {
    Name = "has_k8s"
  }
}

# A security group for making http/https connections inside the VPC. should be added to the admin, ansible, and kubernetes hosts only.
resource "aws_security_group" "vpc_https_from" {
  name        = "vpc_https_from"
  description = "hosts that are allowed to download content from the assethost"
  vpc_id      = module.vpc.vpc_id

  egress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["172.17.0.0/20"]
    }
  egress {
    from_port   = 123
    to_port     = 123
    protocol    = "udp"
    cidr_blocks = ["172.17.0.0/20"]
    }
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["172.17.0.0/20"]
    }

  tags = {
    Name = "vpc_https_from"
  }
}

# A security group for receiving http/https connections inside the VPC. should be added to the asset host only.
resource "aws_security_group" "has_https" {
  name        = "has_https"
  description = "hosts that should be accessable via http. should be only the assethost."
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    security_groups = ["${aws_security_group.vpc_https_from.id}"]
    }
  ingress {
    from_port   = 123
    to_port     = 123
    protocol    = "udp"
    security_groups = ["${aws_security_group.vpc_https_from.id}"]
    }
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    security_groups = ["${aws_security_group.vpc_https_from.id}"]
    }

  tags = {
    Name = "has_https"
  }
}

# our bastion host
resource "aws_instance" "bastion-offline" {
  ami           = "${data.aws_ami.ubuntu18LTS-ARM64.id}"
  instance_type = "a1.medium"
  subnet_id     = "${module.vpc.public_subnets[0]}"
  key_name      = "${aws_key_pair.crash-nonprod-deployer-julia.key_name}"
  tags = {
      Name = "bastion-offline",
      Environment = "offline",
      Role = "bastion"
  }
  vpc_security_group_ids = [
    "${aws_security_group.world_ssh_in.id}",
    "${aws_security_group.world_web_out.id}",
    "${aws_security_group.vpc_ssh_from.id}"
    ]
}

# our admin host
resource "aws_instance" "admin-offline" {
  ami           = "${data.aws_ami.ubuntu18LTS-AMD64.id}"
  instance_type = "m3.medium"
  subnet_id     = "${module.vpc.private_subnets[0]}"
  key_name      = "${aws_key_pair.crash-nonprod-deployer-julia.key_name}"
  tags = {
      Name = "admin-offline",
      Environment = "offline",
      Role = "admin"
  }
  vpc_security_group_ids = [
    "${aws_security_group.vpc_ssh_from.id}",
    "${aws_security_group.vpc_dns_from.id}",
    "${aws_security_group.vpc_https_from.id}",
    "${aws_security_group.has_ssh.id}"
    ]
}

# our vpn endpoint
resource "aws_instance" "vpn-offline" {
  ami           = "${data.aws_ami.ubuntu18LTS-AMD64.id}"
  instance_type = "m3.medium"
  subnet_id     = "${module.vpc.private_subnets[0]}"
  key_name      = "${aws_key_pair.crash-nonprod-deployer-julia.key_name}"
  tags = {
      Name = "vpn-offline",
      Environment = "offline",
      Role = "vpn"
  }
  vpc_security_group_ids = [
    "${aws_security_group.vpc_dns_from.id}",
    "${aws_security_group.vpc_https_from.id}",
    "${aws_security_group.has_ssh.id}"
    ]
}

# our assethost host
resource "aws_instance" "assethost-offline" {
  ami           = "${data.aws_ami.ubuntu18LTS-AMD64.id}"
  instance_type = "m3.medium"
  subnet_id     = "${module.vpc.private_subnets[0]}"
  key_name      = "${aws_key_pair.crash-nonprod-deployer-julia.key_name}"
  root_block_device {
      volume_size = 20
  }
  tags = {
      Name = "assethost-offline",
      Environment = "offline",
      Role = "terminator"
  }
  vpc_security_group_ids = [
    "${aws_security_group.has_ssh.id}",
    "${aws_security_group.has_dns.id}",
    "${aws_security_group.has_https.id}"
    ]
}

# our kubernetes endpoints
resource "aws_instance" "kubepod1-offline" {
  ami           = "${data.aws_ami.ubuntu18LTS-AMD64.id}"
  instance_type = "m3.medium"
  subnet_id     = "${module.vpc.private_subnets[0]}"
  key_name      = "${aws_key_pair.crash-nonprod-deployer-julia.key_name}"
  tags = {
      Name = "kubepod1-offline",
      Environment = "offline",
      Role = "kubepod"
  }
  vpc_security_group_ids = [
    "${aws_security_group.vpc_dns_from.id}",
    "${aws_security_group.vpc_https_from.id}",
    "${aws_security_group.has_ssh.id}",
    "${aws_security_group.vpc_k8s_from.id}",
    "${aws_security_group.has_k8s.id}"
    ]
}

resource "aws_instance" "kubepod2-offline" {
  ami           = "${data.aws_ami.ubuntu18LTS-AMD64.id}"
  instance_type = "m3.medium"
  subnet_id     = "${module.vpc.private_subnets[0]}"
  key_name      = "${aws_key_pair.crash-nonprod-deployer-julia.key_name}"
  tags = {
      Name = "kubepod2-offline",
      Environment = "offline",
      Role = "kubepod"
  }
  vpc_security_group_ids = [
    "${aws_security_group.vpc_dns_from.id}",
    "${aws_security_group.vpc_https_from.id}",
    "${aws_security_group.has_ssh.id}",
    "${aws_security_group.vpc_k8s_from.id}",
    "${aws_security_group.has_k8s.id}"
    ]
}

# our kubernetes endpoints
resource "aws_instance" "kubepod3-offline" {
  ami           = "${data.aws_ami.ubuntu18LTS-AMD64.id}"
  instance_type = "m3.medium"
  subnet_id     = "${module.vpc.private_subnets[0]}"
  key_name      = "${aws_key_pair.crash-nonprod-deployer-julia.key_name}"
  tags = {
      Name = "kubepod3-offline",
      Environment = "offline",
      Role = "kubepod"
  }
  vpc_security_group_ids = [
    "${aws_security_group.vpc_dns_from.id}",
    "${aws_security_group.vpc_https_from.id}",
    "${aws_security_group.has_ssh.id}",
    "${aws_security_group.vpc_k8s_from.id}",
    "${aws_security_group.has_k8s.id}"
    ]
}

# our ephemeral service endpoints
resource "aws_instance" "ansnode1-offline" {
  ami           = "${data.aws_ami.ubuntu18LTS-AMD64.id}"
  instance_type = "m3.medium"
  subnet_id     = "${module.vpc.private_subnets[0]}"
  key_name      = "${aws_key_pair.crash-nonprod-deployer-julia.key_name}"
  tags = {
      Name = "ansnode1-offline",
      Environment = "offline",
      Role = "ansnode"
  }
  vpc_security_group_ids = [
    "${aws_security_group.vpc_dns_from.id}",
    "${aws_security_group.vpc_https_from.id}",
    "${aws_security_group.has_ssh.id}"
    ]
}

resource "aws_instance" "ansnode2-offline" {
  ami           = "${data.aws_ami.ubuntu18LTS-AMD64.id}"
  instance_type = "m3.medium"
  subnet_id     = "${module.vpc.private_subnets[0]}"
  key_name      = "${aws_key_pair.crash-nonprod-deployer-julia.key_name}"
  tags = {
      Name = "ansnode2-offline",
      Environment = "offline",
      Role = "ansnode"
  }
  vpc_security_group_ids = [
    "${aws_security_group.vpc_dns_from.id}",
    "${aws_security_group.vpc_https_from.id}",
    "${aws_security_group.has_ssh.id}"
    ]
}

resource "aws_instance" "ansnode3-offline" {
  ami           = "${data.aws_ami.ubuntu18LTS-AMD64.id}"
  instance_type = "m3.medium"
  subnet_id     = "${module.vpc.private_subnets[0]}"
  key_name      = "${aws_key_pair.crash-nonprod-deployer-julia.key_name}"
  tags = {
      Name = "ansnode3-offline",
      Environment = "offline",
      Role = "ansnode"
  }
  vpc_security_group_ids = [
    "${aws_security_group.vpc_dns_from.id}",
    "${aws_security_group.vpc_https_from.id}",
    "${aws_security_group.has_ssh.id}"
    ]
}

