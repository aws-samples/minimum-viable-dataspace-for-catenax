# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

locals {

  name            = "mvd-for-catenax"
  cluster_version = "1.31"
  region          = "eu-central-1"

  vpc_cidr             = "192.168.0.0/16"
  cluster_service_cidr = "10.96.0.0/16"
  azs                  = slice(data.aws_availability_zones.available.names, 0, 3)

  tags = {
    Project = local.name
    GitRepo = "github.com/aws-samples/minimum-viable-dataspace-for-catenax"
  }
}
