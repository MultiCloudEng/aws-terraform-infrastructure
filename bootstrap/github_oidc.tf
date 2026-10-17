# GitHub Actions authenticates to AWS with short-lived OIDC tokens instead of
# long-lived access keys stored as repository secrets.
#
# Two roles with different trust and permissions:
#   plan  role: only jobs running on the main branch, read-only + state lock
#   apply role: only jobs running in the protected GitHub Environment
#               (which requires a manual reviewer approval)
# Pull requests can assume neither role.

data "aws_caller_identity" "current" {}

locals {
  account_id   = data.aws_caller_identity.current.account_id
  oidc_host    = "token.actions.githubusercontent.com"
  oidc_arn     = var.create_github_oidc_provider ? aws_iam_openid_connect_provider.github[0].arn : "arn:aws:iam::${local.account_id}:oidc-provider/${local.oidc_host}"
  state_object = "${aws_s3_bucket.state.arn}/${var.state_key}"
  state_lock   = "${aws_s3_bucket.state.arn}/${var.state_key}.tflock"
  project_role = "arn:aws:iam::${local.account_id}:role/${var.project}-*"
  project_ip   = "arn:aws:iam::${local.account_id}:instance-profile/${var.project}-*"
}

resource "aws_iam_openid_connect_provider" "github" {
  count          = var.create_github_oidc_provider ? 1 : 0
  url            = "https://${local.oidc_host}"
  client_id_list = ["sts.amazonaws.com"]
}

# ---------------------------------------------------------------------------
# Trust policies
# ---------------------------------------------------------------------------
data "aws_iam_policy_document" "trust_plan" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [local.oidc_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_host}:aud"
      values   = ["sts.amazonaws.com"]
    }
    # Only workflow runs on the main branch (not pull requests, not other branches).
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_host}:sub"
      values   = ["repo:${var.github_repository}:ref:refs/heads/main"]
    }
  }
}

data "aws_iam_policy_document" "trust_apply" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [local.oidc_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_host}:aud"
      values   = ["sts.amazonaws.com"]
    }
    # Only jobs that run in the protected environment. GitHub sets this subject
    # only after the environment's protection rules (reviewer approval) pass.
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_host}:sub"
      values   = ["repo:${var.github_repository}:environment:${var.deploy_environment}"]
    }
  }
}

# ---------------------------------------------------------------------------
# Permissions shared by both roles: read what plan needs + state access
# ---------------------------------------------------------------------------
data "aws_iam_policy_document" "plan" {
  #checkov:skip=CKV_AWS_356:Describe* and GetCallerIdentity do not support resource-level permissions; all other statements are resource-scoped.
  statement {
    sid = "ReadInfrastructure"
    actions = [
      "ec2:Describe*",
      "autoscaling:Describe*",
      "sts:GetCallerIdentity",
    ]
    resources = ["*"] # Describe* calls do not support resource-level permissions.
  }

  statement {
    sid = "ReadProjectIam"
    actions = [
      "iam:GetRole",
      "iam:GetInstanceProfile",
      "iam:ListAttachedRolePolicies",
      "iam:ListRolePolicies",
      "iam:ListInstanceProfilesForRole",
    ]
    resources = [local.project_role, local.project_ip]
  }

  statement {
    sid       = "ReadAmazonLinuxAmiParameter"
    actions   = ["ssm:GetParameter", "ssm:GetParameters"]
    resources = ["arn:aws:ssm:${var.region}::parameter/aws/service/ami-amazon-linux-latest/*"]
  }

  statement {
    sid       = "ListStateBucket"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.state.arn]
  }

  statement {
    sid       = "ReadState"
    actions   = ["s3:GetObject"]
    resources = [local.state_object]
  }

  statement {
    sid       = "StateLock"
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = [local.state_lock]
  }
}

# ---------------------------------------------------------------------------
# Additional permissions for apply, scoped to what this project manages
# ---------------------------------------------------------------------------
data "aws_iam_policy_document" "apply" {
  source_policy_documents = [data.aws_iam_policy_document.plan.json]

  statement {
    sid       = "WriteState"
    actions   = ["s3:PutObject"]
    resources = [local.state_object]
  }

  statement {
    sid = "ManageEc2"
    actions = [
      "ec2:CreateSecurityGroup",
      "ec2:DeleteSecurityGroup",
      "ec2:AuthorizeSecurityGroupIngress",
      "ec2:AuthorizeSecurityGroupEgress",
      "ec2:RevokeSecurityGroupIngress",
      "ec2:RevokeSecurityGroupEgress",
      "ec2:ModifySecurityGroupRules",
      "ec2:CreateLaunchTemplate",
      "ec2:CreateLaunchTemplateVersion",
      "ec2:ModifyLaunchTemplate",
      "ec2:DeleteLaunchTemplate",
      "ec2:RunInstances", # validated by Auto Scaling when it uses the launch template
      "ec2:CreateTags",
      "ec2:DeleteTags",
    ]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "aws:RequestedRegion"
      values   = [var.region]
    }
  }

  statement {
    sid = "ManageAutoScaling"
    actions = [
      "autoscaling:CreateAutoScalingGroup",
      "autoscaling:UpdateAutoScalingGroup",
      "autoscaling:DeleteAutoScalingGroup",
      "autoscaling:CreateOrUpdateTags",
      "autoscaling:DeleteTags",
    ]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "aws:RequestedRegion"
      values   = [var.region]
    }
  }

  # IAM is the main privilege-escalation risk, so it is tightly scoped:
  # only roles/profiles with the project prefix ...
  statement {
    sid = "ManageProjectRoles"
    actions = [
      "iam:CreateRole",
      "iam:DeleteRole",
      "iam:TagRole",
      "iam:UntagRole",
      "iam:UpdateAssumeRolePolicy",
      "iam:CreateInstanceProfile",
      "iam:DeleteInstanceProfile",
      "iam:TagInstanceProfile",
      "iam:UntagInstanceProfile",
      "iam:AddRoleToInstanceProfile",
      "iam:RemoveRoleFromInstanceProfile",
    ]
    resources = [local.project_role, local.project_ip]
  }

  # ... and only the SSM core managed policy may be attached to them.
  # Without this condition, CI could attach AdministratorAccess to a role it
  # creates and escalate its own privileges.
  statement {
    sid       = "AttachOnlySsmCorePolicy"
    actions   = ["iam:AttachRolePolicy", "iam:DetachRolePolicy"]
    resources = [local.project_role]
    condition {
      test     = "ArnEquals"
      variable = "iam:PolicyARN"
      values   = ["arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"]
    }
  }

  statement {
    sid       = "PassProjectRoleToEc2Only"
    actions   = ["iam:PassRole"]
    resources = [local.project_role]
    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["ec2.amazonaws.com"]
    }
  }

  statement {
    sid       = "AutoScalingServiceLinkedRole"
    actions   = ["iam:CreateServiceLinkedRole"]
    resources = ["arn:aws:iam::${local.account_id}:role/aws-service-role/autoscaling.amazonaws.com/*"]
    condition {
      test     = "StringEquals"
      variable = "iam:AWSServiceName"
      values   = ["autoscaling.amazonaws.com"]
    }
  }
}

# ---------------------------------------------------------------------------
# Roles
# ---------------------------------------------------------------------------
resource "aws_iam_role" "github_plan" {
  name                 = "${var.project}-github-plan"
  assume_role_policy   = data.aws_iam_policy_document.trust_plan.json
  max_session_duration = 3600
}

resource "aws_iam_role_policy" "github_plan" {
  name   = "terraform-plan"
  role   = aws_iam_role.github_plan.id
  policy = data.aws_iam_policy_document.plan.json
}

resource "aws_iam_role" "github_apply" {
  name                 = "${var.project}-github-apply"
  assume_role_policy   = data.aws_iam_policy_document.trust_apply.json
  max_session_duration = 3600
}

resource "aws_iam_role_policy" "github_apply" {
  name   = "terraform-apply"
  role   = aws_iam_role.github_apply.id
  policy = data.aws_iam_policy_document.apply.json
}
