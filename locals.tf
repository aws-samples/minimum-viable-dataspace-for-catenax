# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

locals {

  cluster_version = "1.32"
  admin_principal = data.aws_caller_identity.current.arn

  vpc_cidr             = "192.168.0.0/16"
  cluster_service_cidr = "10.96.0.0/16"
  azs                  = slice(data.aws_availability_zones.available.names, 0, 3)

  mxd_repositories = [
    "${var.name}-backend-service"
  ]

  mvd_repositories = [
    "${var.name}-catalog-server",
    "${var.name}-controlplane",
    "${var.name}-dataplane",
    "${var.name}-identity-hub",
    "${var.name}-issuerservice",

    "${var.name}-data-dashboard"
  ]

  tags = {
    Project = var.name
    GitRepo = "github.com/aws-samples/minimum-viable-dataspace-for-catenax"
  }
}
