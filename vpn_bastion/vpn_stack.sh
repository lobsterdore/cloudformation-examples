#!/bin/bash

set -euo pipefail

function main {
    local AMI_ID
    local BUCKET_PREFIX
    local SSH_KEY_NAME
    local S3_STACK_EXISTS
    local VPN_STACK_EXISTS
    local USAGE
    local DIR

    USAGE="$(basename "$0") [BUCKET_PREFIX] [SSH_KEY_PAIR_NAME] [AMI_ID](optional)"
    DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
    BUCKET_PREFIX=${1-}
    SSH_KEY_NAME=${2-}
    AMI_ID=${3-}

    if [[ -z ${BUCKET_PREFIX} ]] || [[ -z ${SSH_KEY_NAME} ]]; then
        echo "Missing required arguments" >&2
        echo "$USAGE" >&2
        exit 1
    fi

    set +e
    aws cloudformation describe-stacks \
        --stack-name vpn-stack-s3 \
        &> /dev/null
    S3_STACK_EXISTS=$?
    aws cloudformation describe-stacks \
        --stack-name vpn-stack \
        &> /dev/null
    VPN_STACK_EXISTS=$?
    set -e

    if [[ -z "${AMI_ID}" ]]; then
      AMI_ID=$( aws ec2 describe-images \
        --owners 099720109477 \
        --filters "Name=name,Values=*ubuntu-xenial-16.04-amd64*" \
          "Name=virtualization-type,Values=hvm" \
          "Name=root-device-type,Values=ebs" \
          "Name=hypervisor,Values=xen" \
        --output text \
        --query "reverse(sort_by(Images, &CreationDate))|[].ImageId | [0]" )
  	fi

    echo "Using AMI ID: ${AMI_ID}"

    if [[ $S3_STACK_EXISTS -ne 0 ]]; then
        echo "Creating vpn s3 stack"

        aws cloudformation create-stack \
            --stack-name vpn-stack-s3 \
            --template-body file://"${DIR}"/vpn_s3_bucket.yaml \
            --parameters \
                ParameterKey=BucketPrefix,ParameterValue="${BUCKET_PREFIX}" \
            &> /dev/null

        aws cloudformation wait stack-create-complete \
            --stack-name vpn-stack-s3

        echo "Stack created"
    fi

    if [[ $VPN_STACK_EXISTS -ne 0 ]]; then
        echo "Creating vpn stack"

        aws cloudformation create-stack \
            --stack-name vpn-stack \
            --template-body file://"${DIR}"/vpn_bastion.yaml \
            --capabilities CAPABILITY_IAM \
            --parameters \
                ParameterKey=ImageId,ParameterValue="${AMI_ID}" \
                ParameterKey=KeyName,ParameterValue="${SSH_KEY_NAME}" \
                ParameterKey=S3VpnKeysBucketName,ParameterValue="${BUCKET_PREFIX}"-vpn-tutorial-keys-bucket \
            &> /dev/null

        aws cloudformation wait stack-create-complete \
            --stack-name vpn-stack

        echo "Stack created"
    else
        echo "Updating vpn stack"

        aws cloudformation update-stack \
            --stack-name vpn-stack \
            --template-body file://"${DIR}"/vpn_bastion.yaml \
            --capabilities CAPABILITY_IAM \
            --parameters \
                ParameterKey=ImageId,ParameterValue="${AMI_ID}" \
                ParameterKey=KeyName,ParameterValue="${SSH_KEY_NAME}" \
                ParameterKey=S3VpnKeysBucketName,ParameterValue="${BUCKET_PREFIX}"-vpn-tutorial-keys-bucket \
            &> /dev/null

        aws cloudformation wait stack-update-complete \
            --stack-name vpn-stack

        echo "Stack updated"
    fi
}

main "$@"
