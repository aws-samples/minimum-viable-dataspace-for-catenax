#!/bin/bash

# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

set -e
CY='\033[0;36m'
NC='\033[0m'

# ---

AWS_REGION="eu-central-1"
PROJECT_NAME="mvd-for-catenax"

# MXD state from 2024-03-19
MXD_COMMIT="55c8231420b2db31ee7b9e21186ed69df29a0dbd"

# ---

KUBE_CONFIG_PATH="~/.kube/config"

function create_mvd {
    echo -e "${CY}Creating Minimum Viable Dataspace for Catena-X on AWS...${NC}"

    echo "Please enter an alphanumeric string to protect access to your connector APIs."
    read -s -p "EDC authentication key: " edc_auth_key

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

    cd tutorial-resources/mxd/
    git checkout "${MXD_COMMIT}"

    sed -e "s|ALICE_DB_ENDPOINT|${alice_db_endpoint}|" -e "s|ALICE_DB_PASSWORD|${alice_db_password}|" \
        -e "s|BOB_DB_ENDPOINT|${bob_db_endpoint}|" -e "s|BOB_DB_PASSWORD|${bob_db_password}|" \
        -e "s|EDC_ACCESS_KEY_ID|${edc_access_key_id}|g" -e "s|EDC_ACCESS_KEY_SECRET|${edc_access_key_secret}|g" ../../templates/main.tf.tpl > main.tf
    sed -e "s|EDC_AUTH_KEY|${edc_auth_key}|g" ../../templates/connector-values.yaml.tpl > modules/connector/values.yaml

    cat ../../templates/connector-main.tf.tpl > modules/connector/main.tf

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
