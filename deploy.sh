#!/bin/bash

# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

set -e
CY="\033[0;36m"
NC="\033[0m"

# ---

AWS_REGION="eu-central-1"
PROJECT_NAME="mvd-for-catenax"

# ---

# MXD state from 2025-03-21
MXD_COMMIT="1e14bba221624c0f2ec2e507dea1109859232465"

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

    # Build MXD runtime images

    cd mxd-runtimes/
    ./gradlew dockerize

    # Performing the above mandatory Gradle build is currently not possible due to https://github.com/eclipse-tractusx/tutorial-resources/issues/545.
    # Tractus-X MXD is as of 2025-05-17 not in a functional state for the upcoming 25.06 release.
    exit 0

    # Push MXD runtime images to ECR

    aws_account_id=$(aws sts get-caller-identity --query Account --output text)
    aws_ecr_registry="${aws_account_id}.dkr.ecr.${AWS_REGION}.amazonaws.com"

    aws ecr get-login-password --region "${AWS_REGION}" | docker login --username AWS --password-stdin "${aws_ecr_registry}"

    docker tag data-service-api:1.0.0   "${aws_ecr_registry}/${PROJECT_NAME}-data-service-api:1.0.0"
    docker tag tx-catalog-server:0.8.0  "${aws_ecr_registry}/${PROJECT_NAME}-tx-catalog-server:0.8.0"
    docker tag tx-identityhub:0.8.0     "${aws_ecr_registry}/${PROJECT_NAME}-tx-identityhub:0.8.0"
    docker tag tx-identityhub-sts:0.8.0 "${aws_ecr_registry}/${PROJECT_NAME}-tx-identityhub-sts:0.8.0"
    docker tag tx-sts:0.8.0             "${aws_ecr_registry}/${PROJECT_NAME}-tx-sts:0.8.0"

    docker push "${aws_ecr_registry}/${PROJECT_NAME}-data-service-api:1.0.0"
    docker push "${aws_ecr_registry}/${PROJECT_NAME}-tx-catalog-server:0.8.0"
    docker push "${aws_ecr_registry}/${PROJECT_NAME}-tx-identityhub:0.8.0"
    docker push "${aws_ecr_registry}/${PROJECT_NAME}-tx-identityhub-sts:0.8.0"
    docker push "${aws_ecr_registry}/${PROJECT_NAME}-tx-sts:0.8.0"

    # Adjust MXD templates

    cd ../mxd/

    sed -e "s|ALICE_DB_ENDPOINT|${alice_db_endpoint}|g" -e "s|ALICE_DB_PASSWORD|${alice_db_password}|g" \
        -e "s|EDC_ACCESS_KEY_ID|${edc_access_key_id}|" -e "s|EDC_ACCESS_KEY_SECRET|${edc_access_key_secret}|" ../../templates/alice.tf.tpl > alice.tf
    sed -e "s|BOB_DB_ENDPOINT|${bob_db_endpoint}|g" -e "s|BOB_DB_PASSWORD|${bob_db_password}|g" \
        -e "s|EDC_ACCESS_KEY_ID|${edc_access_key_id}|" -e "s|EDC_ACCESS_KEY_SECRET|${edc_access_key_secret}|" ../../templates/bob.tf.tpl > bob.tf

    sed -e "s|EDC_AUTH_KEY|${edc_auth_key}|g" ../../templates/connector-values.yaml.tpl > modules/connector/values.yaml

    sed -e "s|password|${edc_auth_key}|" -i postman/mxd-seed.json
    cat ../../templates/connector-connector.tf.tpl > modules/connector/connector.tf

    sed -e "s|data-service-api:latest|${aws_ecr_registry}/${PROJECT_NAME}-data-service-api:1.0.0|"     -i data-service-api.tf
    sed -e "s|tx-catalog-server:latest|${aws_ecr_registry}/${PROJECT_NAME}-tx-catalog-server:0.8.0|"   -i modules/catalog-server/catalog-server.tf
    sed -e "s|tx-identityhub:latest|${aws_ecr_registry}/${PROJECT_NAME}-tx-identityhub:0.8.0|"         -i alice.tf
    sed -e "s|tx-identityhub-sts:latest|${aws_ecr_registry}/${PROJECT_NAME}-tx-identityhub-sts:0.8.0|" -i modules/identity-hub/variables.tf
    sed -e "s|tx-sts:latest|${aws_ecr_registry}/${PROJECT_NAME}-tx-sts:0.8.0|"                         -i modules/sts/sts.tf

    grep -rl "image_pull_policy" ./ | grep -v "terraform" | xargs sed -i "s|Never|IfNotPresent|"
    # Uncomment to allow NLB ingress access to catalog-server and identity-hub
    grep -rl "host = \"localhost\"" | grep -v "terraform" | xargs sed -i "s|localhost||g"

    # Deploy Tractus-X MXD

    terraform init
    terraform apply -auto-approve

    kubectl config set-context --current --namespace=mxd

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
