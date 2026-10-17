locals {
  common_tags = {
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "terraform"
    Repository  = "github.com/MultiCloudEng/aws-terraform-infrastructure"
  }

  ami_id = coalesce(var.ami_id, data.aws_ssm_parameter.al2023_ami.value)
}

# ---------------------------------------------------------------------------
# Networking: default VPC and its subnets (no new VPC = no extra cost)
# ---------------------------------------------------------------------------
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Latest Amazon Linux 2023 AMI, published by AWS. The SSM Agent is preinstalled,
# which is what makes Session Manager work without SSH.
data "aws_ssm_parameter" "al2023_ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

# ---------------------------------------------------------------------------
# Security group shared by the web and api instances
# ---------------------------------------------------------------------------
# The resource was previously called "my_sg". `moved` renames it in state only;
# it does not touch the real security group.
moved {
  from = aws_security_group.my_sg
  to   = aws_security_group.instances
}

resource "aws_security_group" "instances" {
  #checkov:skip=CKV_AWS_23:The group-level description cannot be changed without replacing the security group (see note below); the egress rule has a description.
  # NOTE: name and description are kept unchanged on purpose. Changing either
  # forces AWS to replace the security group, and the old one cannot be deleted
  # while running instances still use it. Rename it after an instance refresh.
  name   = "allow_ssh"
  vpc_id = data.aws_vpc.default.id

  # No ingress rules: there is no public SSH and no inbound traffic at all.
  # Administration goes through AWS Systems Manager Session Manager, which works
  # over an OUTBOUND connection from the SSM Agent to AWS.

  # Outbound HTTPS only. Needed for:
  #  - SSM Session Manager (ssm, ssmmessages, ec2messages endpoints)
  #  - Amazon Linux 2023 package repositories (served over HTTPS)
  # DNS to the VPC resolver is not filtered by security groups.
  egress {
    description = "HTTPS to AWS APIs (SSM) and package repositories"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project}-instances"
  }
}

# ---------------------------------------------------------------------------
# IAM: instance role so the SSM Agent can register with Systems Manager
# ---------------------------------------------------------------------------
data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "instance" {
  name               = "${var.project}-instance-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
}

# AWS managed policy with the minimum permissions for Session Manager
# and SSM core features. No S3, no admin rights.
resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.instance.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "instance" {
  name = "${var.project}-instance-profile"
  role = aws_iam_role.instance.name
}

# ---------------------------------------------------------------------------
# Two self-healing services: web and api
# ---------------------------------------------------------------------------
module "web" {
  source = "./modules/server"

  name                  = "web"
  ami_id                = local.ami_id
  instance_type         = var.instance_type
  security_group_id     = aws_security_group.instances.id
  subnet_ids            = data.aws_subnets.default.ids
  instance_profile_name = aws_iam_instance_profile.instance.name
}

module "api" {
  source = "./modules/server"

  name                  = "api"
  ami_id                = local.ami_id
  instance_type         = var.instance_type
  security_group_id     = aws_security_group.instances.id
  subnet_ids            = data.aws_subnets.default.ids
  instance_profile_name = aws_iam_instance_profile.instance.name
}

# ---------------------------------------------------------------------------
# State bucket is now managed by ./bootstrap
# ---------------------------------------------------------------------------
# The bucket used to be declared here, inside the configuration that stores its
# state in that same bucket (so `destroy` would try to delete its own state).
# This block removes it from THIS state WITHOUT deleting the real bucket.
removed {
  from = aws_s3_bucket.asa_s3

  lifecycle {
    destroy = false
  }
}
