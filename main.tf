# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

provider "aws" {
  region = var.region
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_availability_zones" "available" {}

resource "random_string" "this" {
  length  = 8
  special = false
  upper   = false
}

module "eks" {

  source = "git::https://github.com/terraform-aws-modules/terraform-aws-eks.git?ref=c41b58277ab3951eca8d11863edf178135ec7654"  # commit hash of version 21.10.1

  name                   = var.name
  kubernetes_version     = local.cluster_version
  endpoint_public_access = true

  vpc_id            = local.vpc_id
  subnet_ids        = local.private_subnets
  service_ipv4_cidr = local.cluster_service_cidr

  addons = {
    aws-ebs-csi-driver = {
      pod_identity_association = [
        {
          service_account = "ebs-csi-controller-sa"
          role_arn = aws_iam_role.ebs_csi_driver.arn
        }
      ]
    }
    coredns = {}
    eks-pod-identity-agent = {
      before_compute = true
    }
    kube-proxy = {}
    vpc-cni = {
      before_compute = true
    }
  }

  access_entries = {
    admin-role = {
      kubernetes_groups = []
      principal_arn     = local.admin_principal

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
      principal_arn     = module.iam_user.arn

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
    }
  }

  # Needed for 'dataspace-issuer' service ingress for MVD blueprint
  node_security_group_additional_rules = {
    ingress_allow_80 = {
      description = "Node to node ingress on port 80"
      protocol    = "tcp"
      from_port   = 80
      to_port     = 80
      type        = "ingress"
      self        = true
    }
  }

  tags = local.tags
}

resource "aws_iam_role" "ebs_csi_driver" {
  name = "${var.name}-ebs-csi-driver-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "pods.eks.amazonaws.com"
        }
        Action = [
          "sts:AssumeRole",
          "sts:TagSession"
        ]
      }
    ]
  })

  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "ebs_csi_driver" {
  role       = aws_iam_role.ebs_csi_driver.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

module "ebs_kms_key" {

  source = "git::https://github.com/terraform-aws-modules/terraform-aws-kms.git?ref=926e8c8aac77189686262b6f95e8e6bedcc9acfa"  # commit hash of version 4.1.1

  aliases     = ["eks/${var.name}/ebs"]
  description = "Customer managed key to encrypt EKS managed node group volumes"

  key_administrators = [
    local.admin_principal
  ]

  key_service_roles_for_autoscaling = [
    "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-service-role/autoscaling.amazonaws.com/AWSServiceRoleForAutoScaling",
    module.eks.cluster_iam_role_arn,
  ]

  tags = local.tags
}

data "aws_rds_engine_version" "postgresql" {
  engine  = "aurora-postgresql"
  version = "17.7"
}

resource "random_password" "alice" {
  length  = 32
  special = false
}

module "rds-aurora-alice" {

  source = "git::https://github.com/terraform-aws-modules/terraform-aws-rds-aurora.git?ref=e0462445344641c69e36dc90f7f96ba18b2cc19e"  # commit hash of version 10.0.2

  name              = "${var.name}-alice"
  engine            = data.aws_rds_engine_version.postgresql.engine
  engine_version    = data.aws_rds_engine_version.postgresql.version
  storage_encrypted = true

  database_name               = "alice"
  master_username             = "postgres"
  manage_master_user_password = false
  master_password_wo          = random_password.alice.result
  master_password_wo_version  = 1

  vpc_id               = local.vpc_id
  db_subnet_group_name = local.database_subnet_group_name

  security_group_ingress_rules = {
    private-az1 = {
      cidr_ipv4 = element(local.private_subnets_cidr_blocks, 0)
    }
    private-az2 = {
      cidr_ipv4 = element(local.private_subnets_cidr_blocks, 1)
    }
    private-az3 = {
      cidr_ipv4 = element(local.private_subnets_cidr_blocks, 2)
    }
  }

  apply_immediately   = true
  skip_final_snapshot = true

  cluster_instance_class = "db.t4g.medium"

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

  source = "git::https://github.com/terraform-aws-modules/terraform-aws-rds-aurora.git?ref=e0462445344641c69e36dc90f7f96ba18b2cc19e"  # commit hash of version 10.0.2

  name              = "${var.name}-bob"
  engine            = data.aws_rds_engine_version.postgresql.engine
  engine_version    = data.aws_rds_engine_version.postgresql.version
  storage_encrypted = true

  database_name               = "bob"
  master_username             = "postgres"
  manage_master_user_password = false
  master_password_wo          = random_password.bob.result
  master_password_wo_version  = 1

  vpc_id               = local.vpc_id
  db_subnet_group_name = local.database_subnet_group_name

  security_group_ingress_rules = {
    private-az1 = {
      cidr_ipv4 = element(local.private_subnets_cidr_blocks, 0)
    }
    private-az2 = {
      cidr_ipv4 = element(local.private_subnets_cidr_blocks, 1)
    }
    private-az3 = {
      cidr_ipv4 = element(local.private_subnets_cidr_blocks, 2)
    }
  }

  apply_immediately   = true
  skip_final_snapshot = true

  cluster_instance_class = "db.t4g.medium"

  instances = {
    one = {}
    two = {}
  }

  tags = local.tags
}

resource "aws_iam_policy" "edc_policy" {
  name        = var.name
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

  source = "git::https://github.com/terraform-aws-modules/terraform-aws-iam.git//modules/iam-user?ref=7279fc444aed7e36c60438b46972e1611e48984c"  # commit hash of version 6.2.3

  name          = var.name
  force_destroy = true
  policies      = {
    edc_policy  = aws_iam_policy.edc_policy.arn
  }

  create_login_profile = false

  tags = local.tags
}

module "s3-bucket-alice" {

  source = "git::https://github.com/terraform-aws-modules/terraform-aws-s3-bucket.git?ref=3170c8beeb346b53c10a3ac2164e637ed161f828"  # commit hash of version 5.9.1

  bucket = "${var.name}-alice-${random_string.this.id}"

  tags = local.tags
}

module "s3-bucket-bob" {

  source = "git::https://github.com/terraform-aws-modules/terraform-aws-s3-bucket.git?ref=3170c8beeb346b53c10a3ac2164e637ed161f828"  # commit hash of version 5.9.1

  bucket = "${var.name}-bob-${random_string.this.id}"

  tags = local.tags
}

module "ecr" {

  source   = "git::https://github.com/terraform-aws-modules/terraform-aws-ecr.git?ref=9286de9f9bf6c602f77fa97d27b8ec3939402116"  # commit hash of version 3.1.1
  for_each = toset(var.blueprint == "mvd" ? local.mvd_repositories : local.mxd_repositories)

  repository_name         = each.key
  repository_force_delete = true

  repository_image_tag_mutability   = "MUTABLE"
  repository_read_write_access_arns = [
    local.admin_principal,
    module.iam_user.arn
  ]

  repository_lifecycle_policy = jsonencode({
    rules = [
      {
        rulePriority = 1,
        description  = "Keep only last 3 tagged images",
        selection = {
          tagStatus      = "tagged",
          tagPatternList = ["*.*.*"],
          countType      = "imageCountMoreThan",
          countNumber    = 3
        },
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2,
        description  = "Expire all untagged images",
        selection = {
          tagStatus   = "untagged",
          countType   = "sinceImagePushed",
          countUnit   = "days",
          countNumber = 1
        },
        action = {
          type = "expire"
        }
      }
    ]
  })

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
  kubernetes = {
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
  version    = "3.13.0"

  # Ensure Helm release is purged before EKS access entries are destroyed
  depends_on = [module.eks]
}

resource "helm_release" "ingress_nginx" {
  name       = "ingress-nginx"
  namespace  = "kube-system"
  repository = "https://kubernetes.github.io/ingress-nginx/"
  chart      = "ingress-nginx"
  version    = "4.14.1"

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

resource "kubernetes_config_map_v1" "aurora_multi_db_init_bob" {
  count = var.blueprint == "mvd" ? 1 : 0

  metadata {
    name      = "aurora-multi-db-init-bob"
    namespace = "default"
  }
  data = {
    "init.sql" = <<-EOT
      CREATE DATABASE qna;
      CREATE DATABASE manufacturing;
      CREATE DATABASE identity;
    EOT
  }
}

resource "kubernetes_job_v1" "aurora_multi_db_init_bob" {
  count = var.blueprint == "mvd" ? 1 : 0
  depends_on = [module.rds-aurora-bob.cluster_instances]

  metadata {
    name      = "aurora-multi-db-init-bob"
    namespace = "default"
  }
  spec {
    template {
      metadata {}
      spec {
        container {
          name  = "postgres-client"
          image = "postgres:17.7"
          command = ["psql"]
          args = [
            "-h", module.rds-aurora-bob.cluster_endpoint,
            "-U", "postgres",
            "-d", "bob",
            "-f", "/scripts/init.sql"
          ]
          env {
            name  = "PGPASSWORD"
            value = random_password.bob.result
          }
          volume_mount {
            name       = "init-scripts"
            mount_path = "/scripts"
          }
        }
        volume {
          name = "init-scripts"
          config_map {
            name = kubernetes_config_map_v1.aurora_multi_db_init_bob[0].metadata[0].name
          }
        }
        restart_policy = "Never"
      }
    }
  }
}
