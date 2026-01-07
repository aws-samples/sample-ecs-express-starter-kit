#!/bin/bash
# https://github.com/hashicorp/terraform-provider-aws/issues/23998
# List secrets including those planned for deletion and filter only those that have a DeletedDate
# This indicates they are scheduled/planned for deletion

# Parse the JSON and extract ARNs using jq, then loop through each ARN
aws secretsmanager list-secrets \
    --include-planned-deletion \
    --query 'SecretList[?DeletedDate!=null].ARN' \
    --output json | jq -r '.[]' | while read -r arn; do
    echo "Deleting secret: $arn"
    aws secretsmanager delete-secret \
        --secret-id "$arn" \
        --force-delete-without-recovery \

    # Add a small delay between deletions to prevent throttling
    sleep 2
done