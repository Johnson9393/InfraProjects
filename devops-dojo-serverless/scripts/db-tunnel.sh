#!/bin/bash

set -euo pipefail

###########################################
# Colors
###########################################

COLOR_DEFAULT='\033[0m'
COLOR_BLUE='\033[0;34m'
COLOR_GREEN='\033[0;32m'
COLOR_YELLOW='\033[0;33m'
COLOR_RED='\033[0;31m'

###########################################
# Usage
###########################################

usage() {
    echo ""
    echo "Usage:"
    echo "bash scripts/db-tunnel.sh -e <environment> -p <local_port>"
    echo ""
    echo "Example:"
    echo "bash scripts/db-tunnel.sh -e dev -p 65001"
    echo ""
    exit 1
}

###########################################
# Defaults
###########################################

environment=""
local_port=65001

while getopts "e:p:" option
do
    case "$option" in
        e) environment=$OPTARG ;;
        p) local_port=$OPTARG ;;
        *) usage ;;
    esac
done

[[ -z "$environment" ]] && usage

###########################################
# AWS PROFILE
###########################################

if [[ -z "${AWS_PROFILE:-}" ]]; then
    echo -e "${COLOR_RED}AWS_PROFILE is not exported.${COLOR_DEFAULT}"
    exit 1
fi

echo -e "${COLOR_GREEN}AWS Profile : ${AWS_PROFILE}${COLOR_DEFAULT}"

###########################################
# AWS REGION
###########################################

aws_region="us-east-1"

###########################################
# Find Bastion
###########################################

echo ""
echo -e "${COLOR_YELLOW}Finding Bastion Instance...${COLOR_DEFAULT}"

instance_id=$(aws ec2 describe-instances \
    --region ${aws_region} \
    --filters \
    "Name=tag:Environment,Values=${environment}" \
    "Name=tag:Role,Values=Bastion" \
    "Name=instance-state-name,Values=running" \
    --query "Reservations[].Instances[].InstanceId" \
    --output text)

if [[ -z "${instance_id}" ]]; then
    echo -e "${COLOR_RED}No running Bastion instance found.${COLOR_DEFAULT}"
    exit 1
fi

echo -e "Instance Id : ${COLOR_BLUE}${instance_id}${COLOR_DEFAULT}"

###########################################
# Find RDS Endpoint
###########################################

echo ""
echo -e "${COLOR_YELLOW}Finding RDS Endpoint...${COLOR_DEFAULT}"

db_endpoint=$(aws rds describe-db-instances \
    --region ${aws_region} \
    --query "DBInstances[?contains(DBInstanceIdentifier, '${environment}')].Endpoint.Address" \
    --output text)

if [[ -z "${db_endpoint}" ]]; then
    echo -e "${COLOR_RED}Unable to find RDS Endpoint.${COLOR_DEFAULT}"
    exit 1
fi

echo -e "RDS Endpoint : ${COLOR_BLUE}${db_endpoint}${COLOR_DEFAULT}"

###########################################
# Start Tunnel
###########################################

echo ""
echo -e "${COLOR_GREEN}Starting SSM Tunnel...${COLOR_DEFAULT}"
echo ""
echo "Localhost Port : ${local_port}"
echo ""

aws ssm start-session \
    --target ${instance_id} \
    --document-name AWS-StartPortForwardingSessionToRemoteHost \
    --parameters "{\"host\":[\"${db_endpoint}\"],\"portNumber\":[\"5432\"],\"localPortNumber\":[\"${local_port}\"]}"