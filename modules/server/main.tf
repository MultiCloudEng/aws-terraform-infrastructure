resource "aws_launch_template" "server" {
  name_prefix   = "${var.name}-"
  image_id      = var.ami_id
  instance_type = var.instance_type

  vpc_security_group_ids = [var.security_group_id]

  iam_instance_profile {
    name = var.instance_profile_name
  }

  # Require IMDSv2 (session tokens). Blocks the classic SSRF attack where an
  # application is tricked into reading instance credentials from the metadata service.
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = 8
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = var.name
    }
  }

  tag_specifications {
    resource_type = "volume"
    tags = {
      Name = var.name
    }
  }
}

resource "aws_autoscaling_group" "server" {
  name_prefix      = "${var.name}-asg-"
  min_size         = var.min_size
  max_size         = var.max_size
  desired_capacity = var.desired_capacity

  vpc_zone_identifier = var.subnet_ids

  # EC2 health checks: an instance is replaced if it stops, is terminated or
  # fails the EC2 status checks. There is no load balancer, so application-level
  # (HTTP) health is NOT checked.
  health_check_type         = "EC2"
  health_check_grace_period = 120

  launch_template {
    id = aws_launch_template.server.id
    # An explicit version (instead of "$Latest") makes launch template
    # changes visible in the plan.
    version = aws_launch_template.server.latest_version
  }

  tag {
    key                 = "Name"
    value               = var.name
    propagate_at_launch = true
  }

  lifecycle {
    precondition {
      condition     = var.min_size <= var.desired_capacity && var.desired_capacity <= var.max_size
      error_message = "Require min_size <= desired_capacity <= max_size."
    }
  }
}
