#!/usr/bin/env bash

set -e

if [[ $# -lt 1 ]]; then
  echo "usage: deploy_falco.sh EKS_NODE_ROLE_NAME"
  exit 1
fi

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT_DIR=${CURRENT_DIR}/../

EKS_NODE_ROLE_NAME=$1

function install_binaries() {
    sudo apt update -y
    #install jq
    sudo apt install -y jq
    #install helm
    curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
    chmod 700 get_helm.sh
    ./get_helm.sh
}

function clone_repos() {
    cd "$PROJECT_ROOT_DIR"
    git clone https://github.com/aman-2812/falco-aws-firelens-integration.git || true
    git clone https://github.com/aman-2812/falco-helm-charts.git || true; helm repo add falcosecurity https://falcosecurity.github.io/charts || true
}

function deploy_nginx() {
    kubectl apply -f $CURRENT_DIR/nginx.yaml
}

function create_and_attach_policy() {
    cd $PROJECT_ROOT_DIR
    aws iam create-policy --policy-name EKS-CloudWatchLogs --policy-document file://./falco-aws-firelens-integration/eks/fluent-bit/aws/iam_role_policy.json || true
    echo "Using config that exist!"
    aws iam attach-role-policy --role-name $EKS_NODE_ROLE_NAME --policy-arn `aws iam list-policies | jq -r '.[][] | select(.PolicyName == "EKS-CloudWatchLogs") | .Arn'`
}

function install_fluentbit() {
    echo "Installing Fluentbit"
    kubectl apply -f $PROJECT_ROOT_DIR/falco-aws-firelens-integration/eks/fluent-bit/kubernetes/
}

function install_falco() {
    echo "Installing Falco"
    cd $PROJECT_ROOT_DIR/falco-helm-charts/falco/
    helm dependency build || true
    helm install falco --set tty=true -f values.yaml .
}

install_binaries
clone_repos
deploy_nginx
create_and_attach_policy
install_fluentbit
install_falco