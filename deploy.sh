#!/bin/bash

# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

set -e
CY="\033[0;36m"
NC="\033[0m"

# ---

AWS_REGION="eu-central-1"
PROJECT_NAME="mvd-for-catenax"

# MXD state from 2024-08-13
MXD_COMMIT="8795f19273471194f092f1d1c618d780c69f2a4b"

# ---

# If local Kubernetes credentials exist, make sure Terraform Helm provider uses them
if [ -f "${HOME}/.kube/config" ]; then export KUBE_CONFIG_PATH="${HOME}/.kube/config"; fi

function create_mvd {
    echo -e "${CY}Creating Minimum Viable Dataspace for Catena-X on AWS...${NC}"

    echo "Please enter an alphanumeric string to protect access to your connector APIs."
    read -s -p "EDC authentication key: " edc_auth_key

    # Ensure AWSServiceRoleForAutoScaling exists to prevent https://github.com/hashicorp/terraform-provider-aws/issues/28644
    if ! aws iam get-role --role-name AWSServiceRoleForAutoScaling >/dev/null 2>&1; then
        aws iam create-service-linked-role --aws-service-name autoscaling.amazonaws.com >/dev/null
    fi

    terraform init
    terraform apply -auto-approve

    aws eks update-kubeconfig --region "${AWS_REGION}" --name "${PROJECT_NAME}"

    # Fetch Terraform outputs

    alice_db_endpoint=$(terraform output -raw rds-aurora-alice_endpoint)
    alice_db_password=$(terraform output -raw rds-aurora-alice_password)
    alice_s3_bucket=$(terraform output -raw s3-bucket-alice_id)

    bob_db_endpoint=$(terraform output -raw rds-aurora-bob_endpoint)
    bob_db_password=$(terraform output -raw rds-aurora-bob_password)
    bob_s3_bucket=$(terraform output -raw s3-bucket-bob_id)

    edc_access_key_id=$(terraform output -raw edc_iam-access-key-id)
    edc_access_key_secret=$(terraform output -raw edc_iam-access-key-secret)

    # Clone Tractus-X MXD repository and pin commit

    if [ ! -d "tutorial-resources" ]; then
        git clone https://github.com/eclipse-tractusx/tutorial-resources.git
    fi

    cd tutorial-resources/
    git checkout "${MXD_COMMIT}"

    # Build 'backend-service' image

    cd mxd/backend-service/
    ./gradlew dockerize

    # Push 'backend-service' image to ECR

    aws_account_id=$(aws sts get-caller-identity --query Account --output text)
    aws_ecr_registry="${aws_account_id}.dkr.ecr.${AWS_REGION}.amazonaws.com"

    aws ecr get-login-password --region "${AWS_REGION}" | docker login --username AWS --password-stdin "${aws_ecr_registry}"

    docker tag backend-service:1.0.0 "${aws_ecr_registry}/${PROJECT_NAME}-backend-service:1.0.0"
    docker push "${aws_ecr_registry}/${PROJECT_NAME}-backend-service:1.0.0"

    # Adjust MXD templates

    cd ../

    sed -e "s|ALICE_DB_ENDPOINT|${alice_db_endpoint}|" -e "s|ALICE_DB_PASSWORD|${alice_db_password}|" \
        -e "s|BOB_DB_ENDPOINT|${bob_db_endpoint}|" -e "s|BOB_DB_PASSWORD|${bob_db_password}|" \
        -e "s|EDC_ACCESS_KEY_ID|${edc_access_key_id}|g" -e "s|EDC_ACCESS_KEY_SECRET|${edc_access_key_secret}|g" ../../templates/main.tf.tpl > main.tf
    sed -e "s|EDC_AUTH_KEY|${edc_auth_key}|g" ../../templates/connector-values.yaml.tpl > modules/connector/values.yaml

    sed -e "s|password|${edc_auth_key}|" -i postman/mxd-seed.json
    cat ../../templates/connector-main.tf.tpl > modules/connector/main.tf

    sed -e "s|backend-service:1.0.0|${aws_ecr_registry}/${PROJECT_NAME}-backend-service:1.0.0|" -i backend-service.tf
    grep -rl "image_pull_policy" ./ | grep -v "terraform" | xargs sed -i "s|Never|IfNotPresent|"

    # Fix 'Prefix' path_type - ingress contains invalid paths: path /miw(/|$)(.*) cannot be used with pathType Prefix
    sed -i "34d" ingress.tf

    # Deploy Tractus-X MXD

    terraform init
    terraform apply -auto-approve

    echo -e "${CY}Minimum Viable Dataspace for Catena-X on AWS is up and running.${NC}"
    echo "S3 bucket Alice: ${alice_s3_bucket}"
    echo "S3 bucket Bob: ${bob_s3_bucket}"
}

function delete_mvd {
    echo -e "${CY}Deleting Minimum Viable Dataspace for Catena-X on AWS...${NC}"

    terraform destroy -auto-approve
    rm -rf tutorial-resources

    echo -e "${CY}Minimum Viable Dataspace for Catena-X on AWS is deleted.${NC}"
}

case "$1" in
    up)
        create_mvd
        ;;
    down)
        delete_mvd
        ;;
    *)
        echo -e "${CY}No valid argument provided. Please use either 'up' or 'down'.${NC}"
        ;;
esac
