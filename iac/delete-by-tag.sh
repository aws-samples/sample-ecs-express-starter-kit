#!/usr/bin/env bash
set -euo pipefail

# Configure tag filter
TAG_KEY="Name"
TAG_VALUE="express-mode-demo"

export AWS_REGION=ap-southeast-2
echo "*** Deleting for the REGION ${AWS_REGION}... ***"

# -- Delete Load Balancers --
echo "Finding Load Balancers with tag $TAG_KEY=$TAG_VALUE..."
LB_ARNS=$(aws resourcegroupstaggingapi get-resources \
  --tag-filters Key="$TAG_KEY",Values="$TAG_VALUE" \
  --resource-type-filters elasticloadbalancing:loadbalancer \
  --query 'ResourceTagMappingList[].ResourceARN' \
  --output text)

if [ -n "$LB_ARNS" ]; then
  for ARN in $LB_ARNS; do
    echo "Deleting LB: $ARN"
    aws elbv2 delete-load-balancer --load-balancer-arn "$ARN" || true
  done
else
  echo "No Load Balancers found."
fi

# -- Delete Target Groups --
echo "Finding Target Groups with tag $TAG_KEY=$TAG_VALUE..."
TG_ARNS=$(aws resourcegroupstaggingapi get-resources \
  --tag-filters Key="$TAG_KEY",Values="$TAG_VALUE" \
  --resource-type-filters elasticloadbalancing:targetgroup \
  --query 'ResourceTagMappingList[].ResourceARN' \
  --output text)

if [ -n "$TG_ARNS" ]; then
  for ARN in $TG_ARNS; do
    echo "Deleting TG: $ARN"
    aws elbv2 delete-target-group --target-group-arn "$ARN" || true
  done
else
  echo "No Target Groups found."
fi

# -- Delete Internet Gateways (and cleanup routes) --
echo "Finding Internet Gateways with tag $TAG_KEY=$TAG_VALUE..."
IGWS=$(aws ec2 describe-internet-gateways --filters "Name=tag:${TAG_KEY},Values=${TAG_VALUE}" --query 'InternetGateways[].InternetGatewayId' --output text)

if [ -z "$IGWS" ]; then
  echo "No Internet Gateways found for tag $TAG_KEY=$TAG_VALUE"
else
  for IGW in $IGWS; do
    echo "Processing IGW: $IGW"

    # Get VPC attachments for this IGW
    VPCS=$(aws ec2 describe-internet-gateways --internet-gateway-ids "$IGW" --query 'InternetGateways[].Attachments[].VpcId' --output text)
    for VPC in $VPCS; do
      echo " Cleaning routes in VPC $VPC that point to $IGW"

      # Get route tables in the VPC
      ROUTE_TABLE_IDS=$(aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$VPC" --query 'RouteTables[].RouteTableId' --output text)

      for RT in $ROUTE_TABLE_IDS; do
        # Delete IPv4 routes that reference this IGW
        IPV4_DESTS=$(aws ec2 describe-route-tables --route-table-ids "$RT" --query "RouteTables[].Routes[?GatewayId=='$IGW'].DestinationCidrBlock" --output text)
        for DEST in $IPV4_DESTS; do
          if [ -n "$DEST" ]; then
            echo "  Deleting IPv4 route $DEST from $RT"
            aws ec2 delete-route --route-table-id "$RT" --destination-cidr-block "$DEST" || true
          fi
        done

        # Delete IPv6 routes that reference this IGW
        IPV6_DESTS=$(aws ec2 describe-route-tables --route-table-ids "$RT" --query "RouteTables[].Routes[?GatewayId=='$IGW'].DestinationIpv6CidrBlock" --output text)
        for DEST6 in $IPV6_DESTS; do
          if [ -n "$DEST6" ]; then
            echo "  Deleting IPv6 route $DEST6 from $RT"
            aws ec2 delete-route --route-table-id "$RT" --destination-ipv6-cidr-block "$DEST6" || true
          fi
        done
      done

      echo " Detaching IGW $IGW from VPC $VPC"
      aws ec2 detach-internet-gateway --internet-gateway-id "$IGW" --vpc-id "$VPC" || true
    done

    echo "Deleting Internet Gateway $IGW"
    aws ec2 delete-internet-gateway --internet-gateway-id "$IGW" || true
  done
fi

echo "Done."