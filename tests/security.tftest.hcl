# Offline tests: run with `terraform test` (or `tofu test`).
# The AWS provider is mocked, so no credentials are needed and nothing is created.

mock_provider "aws" {
  mock_resource "aws_launch_template" {
    defaults = {
      id             = "lt-0123456789abcdef0"
      latest_version = 1
    }
  }
  override_data {
    target = data.aws_ssm_parameter.al2023_ami
    values = { value = "ami-0123456789abcdef0" }
  }
  override_data {
    target = data.aws_vpc.default
    values = { id = "vpc-12345678" }
  }
  override_data {
    target = data.aws_subnets.default
    values = { ids = ["subnet-aaaa1111", "subnet-bbbb2222"] }
  }
  override_data {
    target = data.aws_iam_policy_document.ec2_assume_role
    values = { json = "{}" }
  }
}

run "no_inbound_access" {
  command = plan

  assert {
    condition     = length(aws_security_group.instances.ingress) == 0
    error_message = "The instance security group must not allow any inbound traffic."
  }
}

run "egress_is_https_only" {
  command = plan

  assert {
    condition = alltrue([
      for rule in aws_security_group.instances.egress :
      rule.from_port == 443 && rule.to_port == 443 && rule.protocol == "tcp"
    ])
    error_message = "Egress must be limited to TCP 443."
  }
}

run "imdsv2_and_encrypted_disk" {
  command = plan

  assert {
    condition     = module.web.launch_template_metadata_http_tokens == "required"
    error_message = "IMDSv2 must be required."
  }

  assert {
    condition     = module.web.launch_template_root_encrypted
    error_message = "Root volume must be encrypted."
  }
}

run "ssm_instance_profile_attached" {
  command = plan

  assert {
    condition     = aws_iam_role_policy_attachment.ssm_core.policy_arn == "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
    error_message = "Instances need the SSM core policy for Session Manager."
  }
}

run "default_ami_is_amazon_linux" {
  command = plan

  assert {
    condition     = local.ami_id == "ami-0123456789abcdef0"
    error_message = "With ami_id = null the Amazon Linux 2023 SSM parameter must be used."
  }
}

run "rejects_large_instance_type" {
  command = plan
  variables {
    instance_type = "m5.4xlarge"
  }
  expect_failures = [var.instance_type]
}

run "rejects_invalid_ami" {
  command = plan
  variables {
    ami_id = "not-an-ami"
  }
  expect_failures = [var.ami_id]
}

run "rejects_invalid_environment" {
  command = plan
  variables {
    environment = "production-eu"
  }
  expect_failures = [var.environment]
}
