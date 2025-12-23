# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

terraform {
  required_version = ">= 1.14.3"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.27.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 3.0.1"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 3.1.1"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.7.2"
    }
  }
}
