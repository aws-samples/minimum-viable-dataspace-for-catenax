# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

provider "aws" {
  region = local.region
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_availability_zones" "available" {}

resource "random_string" "this" {
  length  = 8
  special = false
  upper   = false
}

module "vpc" {

  source = "git::https://github.com/terraform-aws-modules/terraform-aws-vpc.git?ref=652598fd6eb64b405e8535e807cb2f239a6da924"  # commit hash of version 5.12.1

  name = local.name
  cidr = local.vpc_cidr

  azs              = local.azs
  public_subnets   = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k)]
  private_subnets  = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k + 3)]
  database_subnets = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k + 6)]

  enable_nat_gateway   = true
  create_igw           = true
  enable_dns_hostnames = true
  single_nat_gateway   = true

  # Manage so we can name
  manage_default_network_acl    = true
  default_network_acl_tags      = { Name = "${local.name}-default" }
  manage_default_route_table    = true
  default_route_table_tags      = { Name = "${local.name}-default" }
  manage_default_security_group = true
  default_security_group_tags   = { Name = "${local.name}-default" }  

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }

  tags = local.tags
}

module "eks" {

  source = "git::https://github.com/terraform-aws-modules/terraform-aws-eks.git?ref=1360e3de68d4b18048477cef43d74c3dc0dd081b"  # commit hash of version 20.23.0

  cluster_name                   = local.name
  cluster_version                = local.cluster_version
  cluster_endpoint_public_access = true

  vpc_id                    = module.vpc.vpc_id
  subnet_ids                = module.vpc.private_subnets
  cluster_service_ipv4_cidr = local.cluster_service_cidr

  cluster_addons = {
    aws-ebs-csi-driver = {
      most_recent = true
    }
  }

  access_entries = {
    admin-role = {
      kubernetes_groups = []
      principal_arn     = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/Admin"

      policy_associations = {
        cluster-admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
    admin-user = {
      kubernetes_groups = []
      principal_arn     = module.iam_user.iam_user_arn

      policy_associations = {
        admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSAdminPolicy"
          access_scope = {
            namespaces = ["default"]
            type       = "namespace"
          }
        }
      }
    }
  }

  eks_managed_node_groups = {
    mng_ondemand = {
      instance_types = ["t3a.medium"]
#     capacity_type  = "SPOT"

      min_size     = 1
      max_size     = 3
      desired_size = 2

      block_device_mappings = {
        xvda = {
          device_name = "/dev/xvda"
          ebs = {
            volume_size           = 20
            volume_type           = "gp3"
            iops                  = 3000
            throughput            = 125
            encrypted             = true
            kms_key_id            = module.ebs_kms_key.key_arn
            delete_on_termination = true
          }
        }
      }

      iam_role_additional_policies = {
        AmazonEBSCSIDriverPolicy = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
      }
    }
  }

  tags = local.tags
}

module "ebs_kms_key" {

  source = "git::https://github.com/terraform-aws-modules/terraform-aws-kms.git?ref=fe1beca2118c0cb528526e022a53381535bb93cd"  # commit hash of version 3.1.0

  aliases     = ["eks/${local.name}/ebs"]
  description = "Customer managed key to encrypt EKS managed node group volumes"

  key_administrators = [
    "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/Admin"
  ]

  key_service_roles_for_autoscaling = [
    "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-service-role/autoscaling.amazonaws.com/AWSServiceRoleForAutoScaling",
    module.eks.cluster_iam_role_arn,
  ]

  tags = local.tags
}

data "aws_rds_engine_version" "postgresql" {
  engine  = "aurora-postgresql"
  version = "16.3"
}

resource "random_password" "alice" {
  length  = 32
  special = false
}

module "rds-aurora-alice" {

  source = "git::https://github.com/terraform-aws-modules/terraform-aws-rds-aurora.git?ref=5a2ebc23062c694f7d1f315114caf02bdb1be228"  # commit hash of version 9.8.0

  name              = "${local.name}-alice"
  engine            = data.aws_rds_engine_version.postgresql.engine
  engine_version    = data.aws_rds_engine_version.postgresql.version
  storage_encrypted = true
  master_username   = "postgres"
  master_password   = random_password.alice.result

  database_name               = "alice"
  manage_master_user_password = false

  vpc_id               = module.vpc.vpc_id
  db_subnet_group_name = module.vpc.database_subnet_group_name
  security_group_rules = {
    vpc_ingress = {
      cidr_blocks = module.vpc.private_subnets_cidr_blocks
    }
  }

  apply_immediately   = true
  skip_final_snapshot = true

  instance_class = "db.t4g.medium"

  instances = {
    one = {}
    two = {}
  }

  tags = local.tags
}

resource "random_password" "bob" {
  length  = 32
  special = false
}

module "rds-aurora-bob" {

  source = "git::https://github.com/terraform-aws-modules/terraform-aws-rds-aurora.git?ref=5a2ebc23062c694f7d1f315114caf02bdb1be228"  # commit hash of version 9.8.0

  name              = "${local.name}-bob"
  engine            = data.aws_rds_engine_version.postgresql.engine
  engine_version    = data.aws_rds_engine_version.postgresql.version
  storage_encrypted = true
  master_username   = "postgres"
  master_password   = random_password.bob.result

  database_name               = "bob"
  manage_master_user_password = false

  vpc_id               = module.vpc.vpc_id
  db_subnet_group_name = module.vpc.database_subnet_group_name
  security_group_rules = {
    vpc_ingress = {
      cidr_blocks = module.vpc.private_subnets_cidr_blocks
    }
  }

  apply_immediately   = true
  skip_final_snapshot = true

  instance_class = "db.t4g.medium"

  instances = {
    one = {}
    two = {}
  }

  tags = local.tags
}

resource "aws_iam_policy" "edc_policy" {
  name        = local.name
  description = "Policy for EDC access to AWS services"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:AbortMultipartUpload",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:ListBucketMultipartUploads",
          "s3:ListMultipartUploadParts",
          "s3:PutObject",
        ]
        Effect   = "Allow"
        Resource = [
          "${module.s3-bucket-alice.s3_bucket_arn}",
          "${module.s3-bucket-alice.s3_bucket_arn}/*",
          "${module.s3-bucket-bob.s3_bucket_arn}",
          "${module.s3-bucket-bob.s3_bucket_arn}/*",
        ]
      },
      {
        Action = [
          "s3:ListAllMyBuckets",
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

module "iam_user" {

  source = "git::https://github.com/terraform-aws-modules/terraform-aws-iam.git//modules/iam-user?ref=89fe17a6549728f1dc7e7a8f7b707486dfb45d89"  # commit hash of version 5.44.0

  name          = local.name
  force_destroy = true
  policy_arns   = [
    aws_iam_policy.edc_policy.arn
  ]

  create_iam_user_login_profile = false

  tags = local.tags
}

module "s3-bucket-alice" {

  source = "git::https://github.com/terraform-aws-modules/terraform-aws-s3-bucket.git?ref=8a0b697adfbc673e6135c70246cff7f8052ad95a"  # commit hash of version 4.1.2

  bucket = "${local.name}-alice-${random_string.this.id}"

  tags = local.tags
}

module "s3-bucket-bob" {

  source = "git::https://github.com/terraform-aws-modules/terraform-aws-s3-bucket.git?ref=8a0b697adfbc673e6135c70246cff7f8052ad95a"  # commit hash of version 4.1.2

  bucket = "${local.name}-bob-${random_string.this.id}"

  tags = local.tags
}

resource "tls_private_key" "this" {
  algorithm = "RSA"
}

resource "tls_self_signed_cert" "this" {
  private_key_pem = tls_private_key.this.private_key_pem

  subject {
    common_name  = "mvd.example.com"
    organization = "ACME Examples, Inc"
  }

  validity_period_hours = 720

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
}

resource "aws_acm_certificate" "nlb" {
  private_key      = tls_private_key.this.private_key_pem
  certificate_body = tls_self_signed_cert.this.cert_pem
}

data "aws_eks_cluster" "this" {
  name = module.eks.cluster_name
  depends_on = [
    module.eks.eks_managed_node_groups
  ]
}

data "aws_eks_cluster_auth" "this" {
  name = module.eks.cluster_name
  depends_on = [
    module.eks.eks_managed_node_groups
  ]
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.this.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority.0.data)
  token                  = data.aws_eks_cluster_auth.this.token
}

provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.this.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority.0.data)
    token                  = data.aws_eks_cluster_auth.this.token
  }
}

resource "helm_release" "metrics_server" {
  name       = "metrics-server"
  namespace  = "kube-system"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  version    = "3.12.1"

  # Ensure Helm release is purged before EKS access entries are destroyed
  depends_on = [module.eks]
}

resource "helm_release" "ingress_nginx" {
  name       = "ingress-nginx"
  namespace  = "kube-system"
  repository = "https://kubernetes.github.io/ingress-nginx/"
  chart      = "ingress-nginx"
  version    = "4.11.1"

  values = [
    yamlencode({

      controller = {
        service = {
          annotations = {
            "service.beta.kubernetes.io/aws-load-balancer-type"                              = "nlb",
            "service.beta.kubernetes.io/aws-load-balancer-cross-zone-load-balancing-enabled" = "true",
            "service.beta.kubernetes.io/aws-load-balancer-ssl-ports"                         = "https",
            "service.beta.kubernetes.io/aws-load-balancer-ssl-cert"                          = aws_acm_certificate.nlb.arn,
            "service.beta.kubernetes.io/aws-load-balancer-backend-protocol"                  = "http",
          },
          targetPorts = {
            http  = "tohttps",
            https = "http",
          }
        }
      }

    })
  ]

  # Ensure Helm release is purged before EKS access entries are destroyed
  depends_on = [module.eks]
}
