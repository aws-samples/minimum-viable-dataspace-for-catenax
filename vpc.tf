# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

data "aws_vpc" "existing" {
  count = var.existing_vpc_id != "" ? 1 : 0
  id    = var.existing_vpc_id
}

data "aws_subnets" "existing_private" {
  count = var.existing_vpc_id != "" ? 1 : 0

  filter {
    name   = "vpc-id"
    values = [var.existing_vpc_id]
  }

  tags = {
    "kubernetes.io/role/internal-elb" = "1"
  }
}

data "aws_subnets" "existing_public" {
  count = var.existing_vpc_id != "" ? 1 : 0

  filter {
    name   = "vpc-id"
    values = [var.existing_vpc_id]
  }

  tags = {
    "kubernetes.io/role/elb" = "1"
  }
}

data "aws_subnet" "existing_private" {
  count = var.existing_vpc_id != "" ? length(data.aws_subnets.existing_private[0].ids) : 0
  id    = data.aws_subnets.existing_private[0].ids[count.index]
}

locals {
  use_existing_vpc = var.existing_vpc_id != ""

  existing_private_subnets = local.use_existing_vpc ? data.aws_subnets.existing_private[0].ids : []
  existing_public_subnets  = local.use_existing_vpc ? data.aws_subnets.existing_public[0].ids : []

  min_required_subnets = 2

  vpc_id = local.use_existing_vpc ? var.existing_vpc_id : module.vpc[0].vpc_id

  private_subnets = local.use_existing_vpc ? local.existing_private_subnets : module.vpc[0].private_subnets
  public_subnets  = local.use_existing_vpc ? local.existing_public_subnets : module.vpc[0].public_subnets

  private_subnets_cidr_blocks = local.use_existing_vpc ? data.aws_subnet.existing_private[*].cidr_block : module.vpc[0].private_subnets_cidr_blocks
  database_subnet_group_name  = local.use_existing_vpc ? aws_db_subnet_group.existing[0].name : module.vpc[0].database_subnet_group_name
}

resource "null_resource" "validate_existing_vpc" {
  count = local.use_existing_vpc ? 1 : 0

  lifecycle {
    precondition {
      condition = length(local.existing_private_subnets) >= local.min_required_subnets
      error_message = "Existing VPC must have at least ${local.min_required_subnets} private subnets tagged with 'kubernetes.io/role/internal-elb=1'"
    }

    precondition {
      condition = length(local.existing_public_subnets) >= local.min_required_subnets
      error_message = "Existing VPC must have at least ${local.min_required_subnets} public subnets tagged with 'kubernetes.io/role/elb=1'"
    }
  }
}

resource "aws_db_subnet_group" "existing" {
  count = local.use_existing_vpc ? 1 : 0

  name       = "${var.name}-database"
  subnet_ids = local.existing_private_subnets

  tags = merge(local.tags, {
    Name = "${var.name}-database"
  })
}

module "vpc" {
  count = local.use_existing_vpc ? 0 : 1

  source = "git::https://github.com/terraform-aws-modules/terraform-aws-vpc.git?ref=cf73787bc163944d63a82e0898aee2bc7ade27ca"  # commit hash of version 6.5.1

  name = var.name
  cidr = local.vpc_cidr

  azs              = local.azs
  public_subnets   = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k)]
  private_subnets  = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k + 3)]
  database_subnets = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k + 6)]

  enable_nat_gateway   = true
  create_igw           = true
  enable_dns_hostnames = true
  single_nat_gateway   = true

  manage_default_network_acl    = true
  default_network_acl_tags      = { Name = "${var.name}-default" }
  manage_default_route_table    = true
  default_route_table_tags      = { Name = "${var.name}-default" }
  manage_default_security_group = true
  default_security_group_tags   = { Name = "${var.name}-default" }

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }

  tags = local.tags
}
