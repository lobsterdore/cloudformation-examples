#!/bin/bash

set -euo pipefail

# ha_willreplace_stack_update.sh
# Usage: ha_willreplace_stack_update.sh [AMI_ID] [SSH_KEY_PAIR_NAME]

function main {
    local AMI_ID
    local SSH_KEY_NAME
    local ASG_ID
    local ASG_CURRENT_INSTANCE_COUNT

    AMI_ID=${1-}
    SSH_KEY_NAME=${2-}

    if [[ -z ${AMI_ID} ]] || [[ -z ${SSH_KEY_NAME} ]]; then
        echo "Missing required arguments" >&2
        exit 1
    fi

    # Grab ASG ID
    ASG_ID=$( aws cloudformation describe-stacks \
        --stack-name ha-willreplace \
        --query "Stacks[0].Outputs[?OutputKey=='AutoScalingGroup'].OutputValue" \
        --output text )

    # Grab current instance count from ASG
    ASG_CURRENT_INSTANCE_COUNT=$( aws autoscaling describe-auto-scaling-groups \
        --auto-scaling-group-names "${ASG_ID}" \
        --query "AutoScalingGroups[0].DesiredCapacity" \
        --output text )

    echo "Current instance count: ${ASG_CURRENT_INSTANCE_COUNT}"

    # Update stack
    aws cloudformation update-stack \
        --stack-name ha-willreplace \
        --template-body file://ha_willreplace.template.yaml \
        --parameters \
            ParameterKey=KeyName,ParameterValue="${SSH_KEY_NAME}" \
            ParameterKey=InstanceCount,ParameterValue="${ASG_CURRENT_INSTANCE_COUNT}" \
            ParameterKey=InstanceImageId,ParameterValue="${AMI_ID}"

    aws cloudformation wait stack-update-complete \
        --stack-name ha-willreplace

    echo "Stack updated"
}

main "$@"
