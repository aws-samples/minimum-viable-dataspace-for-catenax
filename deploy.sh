#!/bin/bash

# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

set -e
CY="\033[0;36m"
NC="\033[0m"

# ---

AWS_REGION="eu-central-1"
PROJECT_NAME="mvd-on-aws"

# Tractus-X - MXD state from 2024-08-13
MXD_COMMIT="8795f19273471194f092f1d1c618d780c69f2a4b"

# Eclipse   - MVD state from 2025-04-07
MVD_COMMIT="140f18c8f79d035bd42fb38e621f7a345f177875"

# ---

# If local Kubernetes credentials exist, make sure Terraform Helm provider uses them
if [ -f "${HOME}/.kube/config" ]; then export KUBE_CONFIG_PATH="${HOME}/.kube/config"; fi

function create_mvd {
    echo -e "${CY}Creating Minimum Viable Dataspace on AWS...${NC}"

    echo "Please enter an alphanumeric string to protect access to your connector APIs."
    read -s -p "EDC authentication key: " edc_auth_key
    echo

    # Ensure AWSServiceRoleForAutoScaling exists to prevent https://github.com/hashicorp/terraform-provider-aws/issues/28644
    if ! aws iam get-role --role-name AWSServiceRoleForAutoScaling >/dev/null 2>&1; then
        aws iam create-service-linked-role --aws-service-name autoscaling.amazonaws.com >/dev/null
    fi

    blueprint="$1"

    terraform init
    terraform apply -auto-approve -var name="${PROJECT_NAME}" -var region="${AWS_REGION}" -var blueprint="${blueprint}"

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

    # Deploy MVD on AWS blueprint

    case "$blueprint" in
        mxd)
            deploy_blueprint_mxd
            ;;
        mvd)
            deploy_blueprint_mvd
            ;;
        *)
            echo -e "${CY}Something went wrong. Exiting.${NC}"
            exit 1
            ;;
    esac

    echo -e "${CY}Minimum Viable Dataspace on AWS is up and running.${NC}"
    echo -e "Blueprint: '${blueprint}'"
    echo
    echo -e "S3 bucket Alice: ${alice_s3_bucket}"
    echo -e "S3 bucket Bob: ${bob_s3_bucket}"
}

function deploy_blueprint_mxd {
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
        -e "s|EDC_ACCESS_KEY_ID|${edc_access_key_id}|g" -e "s|EDC_ACCESS_KEY_SECRET|${edc_access_key_secret}|g" ../../templates/mxd/main.tf.tpl > main.tf
    sed -e "s|EDC_AUTH_KEY|${edc_auth_key}|g" ../../templates/mxd/connector-values.yaml.tpl > modules/connector/values.yaml

    sed -e "s|password|${edc_auth_key}|" -i postman/mxd-seed.json
    cat ../../templates/mxd/connector-main.tf.tpl > modules/connector/main.tf

    sed -e "s|backend-service:1.0.0|${aws_ecr_registry}/${PROJECT_NAME}-backend-service:1.0.0|" -i backend-service.tf
    grep -rl "image_pull_policy" ./ | grep -v "terraform" | xargs sed -i "s|Never|IfNotPresent|"

    # Fix 'Prefix' path_type - ingress contains invalid paths: path /miw(/|$)(.*) cannot be used with pathType Prefix
    sed -i "34d" ingress.tf

    # Deploy Tractus-X MXD

    terraform init
    terraform apply -auto-approve
}

function deploy_blueprint_mvd {
    # Clone Eclipse MVD repository and pin commit

    if [ ! -d "MinimumViableDataspace" ]; then
        git clone https://github.com/eclipse-edc/MinimumViableDataspace.git
    fi

    cd MinimumViableDataspace/
    git checkout "${MVD_COMMIT}"

    # Build MVD container images

    ./gradlew build
    ./gradlew -Ppersistence=true dockerize

    # Push MVD container images to ECR

    aws_account_id=$(aws sts get-caller-identity --query Account --output text)
    aws_ecr_registry="${aws_account_id}.dkr.ecr.${AWS_REGION}.amazonaws.com"

    aws ecr get-login-password --region "${AWS_REGION}" | docker login --username AWS --password-stdin "${aws_ecr_registry}"

    docker tag issuerservice:0.12.0  "${aws_ecr_registry}/${PROJECT_NAME}-issuerservice:0.12.0"
    docker tag identity-hub:0.12.0   "${aws_ecr_registry}/${PROJECT_NAME}-identity-hub:0.12.0"
    docker tag dataplane:0.12.0      "${aws_ecr_registry}/${PROJECT_NAME}-dataplane:0.12.0"
    docker tag controlplane:0.12.0   "${aws_ecr_registry}/${PROJECT_NAME}-controlplane:0.12.0"
    docker tag catalog-server:0.12.0 "${aws_ecr_registry}/${PROJECT_NAME}-catalog-server:0.12.0"

    docker push "${aws_ecr_registry}/${PROJECT_NAME}-issuerservice:0.12.0"
    docker push "${aws_ecr_registry}/${PROJECT_NAME}-identity-hub:0.12.0"
    docker push "${aws_ecr_registry}/${PROJECT_NAME}-dataplane:0.12.0"
    docker push "${aws_ecr_registry}/${PROJECT_NAME}-controlplane:0.12.0"
    docker push "${aws_ecr_registry}/${PROJECT_NAME}-catalog-server:0.12.0"

    # Adjust MVD templates

    cd deployment/
    grep -rl "\"password\"" ./ | grep -v "terraform" | xargs sed -ie "s|\"password\"|\"${edc_auth_key}\"|g"

    # Pin Terraform Helm provider version of Eclipse MVD to v2.x.x
    sed -i "33i\      version = \"< 3.0.0\"" main.tf

    sed -e "s|issuerservice:latest|${aws_ecr_registry}/${PROJECT_NAME}-issuerservice:0.12.0|"   -i modules/issuer/main.tf
    sed -e "s|identity-hub:latest|${aws_ecr_registry}/${PROJECT_NAME}-identity-hub:0.12.0|"     -i modules/identity-hub/main.tf
    sed -e "s|dataplane:latest|${aws_ecr_registry}/${PROJECT_NAME}-dataplane:0.12.0|"           -i modules/connector/dataplane.tf
    sed -e "s|controlplane:latest|${aws_ecr_registry}/${PROJECT_NAME}-controlplane:0.12.0|"     -i modules/connector/controlplane.tf
    sed -e "s|catalog-server:latest|${aws_ecr_registry}/${PROJECT_NAME}-catalog-server:0.12.0|" -i modules/catalog-server/catalog-server.tf

    grep -rl "image_pull_policy" ./ | grep -v "terraform" | xargs sed -i "s|Never|IfNotPresent|"

    # Deploy Eclipse MVD

    terraform init
    terraform apply -auto-approve

    kubectl config set-context --current --namespace=mvd
    cd ../

    sleep 5
    nlb_address=$(kubectl get ing | awk 'NR==2 { print $4 }')
    sed -e "s|NLB_ADDRESS|${nlb_address}|g" ../templates/mvd/seed-k8s.sh.tpl > seed-k8s.sh

    ./seed-k8s.sh
}

function delete_mvd {
    echo -e "${CY}Deleting Minimum Viable Dataspace on AWS...${NC}"

    terraform destroy -auto-approve

    if [ -d "tutorial-resources" ];     then rm -rf tutorial-resources; fi
    if [ -d "MinimumViableDataspace" ]; then rm -rf MinimumViableDataspace; fi

    echo -e "${CY}Minimum Viable Dataspace on AWS was deleted successfully.${NC}"
}

case "$1" in
    up)
        if ! [[ "$2" =~ ^(mxd|mvd)$ ]]; then
            echo -e "Usage: ./deploy.sh up [blueprint]"
            echo
            echo -e "${CY}No valid blueprint provided. Please use either 'mxd' or 'mvd'.${NC}"

            exit 1
        fi

        create_mvd "$2"
        ;;
    down)
        delete_mvd
        ;;
    *)
        echo -e "Usage: ./deploy.sh [command] [blueprint]"
        echo
        echo -e "Commands:"
        echo -e "  up [blueprint] Deploy Minimum Viable Dataspace on AWS using a given blueprint"
        echo -e "  down           Delete Minimum Viable Dataspace on AWS"
        echo
        echo -e "Blueprints:"
        echo -e "  mxd            Use Tractus-X MXD as deployment blueprint"
        echo -e "  mvd            Use Eclipse MVD as deployment blueprint"

        exit 1
        ;;
esac
