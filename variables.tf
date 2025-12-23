# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

variable "name" {
  default = "mvd-on-aws"
}

variable "region" {
  default = "eu-central-1"
}

variable "blueprint" {
  default = "mvd"
}

variable "existing_vpc_id" {
  default = ""
}
