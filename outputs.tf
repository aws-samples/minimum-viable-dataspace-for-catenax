# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

# Aurora

output "rds-aurora-alice_endpoint" {
  value = module.rds-aurora-alice.cluster_endpoint
}

output "rds-aurora-alice_password" {
  value     = random_password.alice.result
  sensitive = true
}

output "rds-aurora-bob_endpoint" {
  value = module.rds-aurora-bob.cluster_endpoint
}

output "rds-aurora-bob_password" {
  value     = random_password.bob.result
  sensitive = true
}

# S3

output "s3-bucket-alice_id" {
  value = module.s3-bucket-alice.s3_bucket_id
}

output "s3-bucket-bob_id" {
  value = module.s3-bucket-bob.s3_bucket_id
}

# IAM

output "edc_iam-access-key-id" {
  value = module.iam_user.access_key_id
}

output "edc_iam-access-key-secret" {
  value     = module.iam_user.access_key_secret
  sensitive = true
}
