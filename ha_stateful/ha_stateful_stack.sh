#!/bin/bash

set -euo pipefail

# ha_stateful_stack.sh
# Usage: ha_stateful_stack.sh [AMI_ID] [SERVICE_TYPE] [SSH_KEY_PAIR_NAME]

function main {
    local AMI_ID
    local SERVICE_TYPE
    local SSH_KEY_NAME
    local STACK_EXISTS

    AMI_ID=${1-}
    SERVICE_TYPE=${2-}
    SSH_KEY_NAME=${3-}

    if [[ -z ${AMI_ID} ]] || [[ -z ${SERVICE_TYPE} ]] || [[ -z ${SSH_KEY_NAME} ]]; then
        echo "Missing required arguments" >&2
        exit 1
    fi

    set +e
    aws cloudformation describe-stacks \
        --stack-name ha-stateful-"${SERVICE_TYPE}"
    STACK_EXISTS=$?
    set -e

    if [[ $STACK_EXISTS -ne 0 ]]; then
        echo "Creating stack"

        aws cloudformation create-stack \
            --stack-name ha-stateful-"${SERVICE_TYPE}" \
            --template-body file://ha_stateful."${SERVICE_TYPE}".template.yaml \
            --capabilities CAPABILITY_IAM \
            --parameters \
                ParameterKey=KeyName,ParameterValue="${SSH_KEY_NAME}" \
                ParameterKey=InstanceImageId,ParameterValue="${AMI_ID}"

        aws cloudformation wait stack-create-complete \
            --stack-name ha-stateful-"${SERVICE_TYPE}"

        echo "Stack created"
    else
        echo "Updating stack"

        aws cloudformation update-stack \
            --stack-name ha-stateful-"${SERVICE_TYPE}" \
            --template-body file://ha_stateful."${SERVICE_TYPE}".template.yaml \
            --capabilities CAPABILITY_IAM \
            --parameters \
                ParameterKey=KeyName,ParameterValue="${SSH_KEY_NAME}" \
                ParameterKey=InstanceImageId,ParameterValue="${AMI_ID}"

        aws cloudformation wait stack-update-complete \
            --stack-name ha-stateful-"${SERVICE_TYPE}"

        echo "Stack updated"
    fi
}

main "$@"
