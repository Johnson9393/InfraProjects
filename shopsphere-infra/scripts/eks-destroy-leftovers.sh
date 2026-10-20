#!/usr/bin/env bash
# Leftovers EKS creates outside Terraform (ALBs, CNI ENIs, default cluster SG).
# Safe to run from GitHub destroy or a laptop after a failed destroy.
# Does nothing harmful if the cluster is still ACTIVE (skips ENI/SG wipe).
set -u

AWS_REGION="${AWS_REGION:-us-east-1}"
TF_ENV="${TF_ENV:-dev}"
CLUSTER_NAME="${CLUSTER_NAME:-${TF_ENV}-shopsphere}"
VPC_NAME="${VPC_NAME:-${TF_ENV}-shopsphere-vpc}"

echo "==> leftovers: cluster=${CLUSTER_NAME} vpc_name=${VPC_NAME} region=${AWS_REGION}"

cluster_active() {
  local status
  status="$(
    aws eks describe-cluster --name "${CLUSTER_NAME}" --region "${AWS_REGION}" \
      --query 'cluster.status' --output text 2>/dev/null || true
  )"
  [[ "${status}" == "ACTIVE" || "${status}" == "CREATING" || "${status}" == "UPDATING" ]]
}

delete_ingresses_if_cluster_up() {
  if ! cluster_active; then
    echo "==> cluster not active; skip ingress delete"
    return 0
  fi
  echo "==> deleting Ingress objects so the controller can drop the ALB"
  aws eks update-kubeconfig --name "${CLUSTER_NAME}" --region "${AWS_REGION}" || return 0
  kubectl delete ingress --all -A --ignore-not-found || true
}

delete_cluster_albs() {
  echo "==> ALBs tagged elbv2.k8s.aws/cluster=${CLUSTER_NAME}"
  local arn cluster_tag
  for arn in $(
    aws elbv2 describe-load-balancers --region "${AWS_REGION}" \
      --query 'LoadBalancers[].LoadBalancerArn' --output text 2>/dev/null || true
  ); do
    [[ -z "${arn}" || "${arn}" == "None" ]] && continue
    cluster_tag="$(
      aws elbv2 describe-tags --region "${AWS_REGION}" --resource-arns "${arn}" \
        --query "TagDescriptions[0].Tags[?Key=='elbv2.k8s.aws/cluster'].Value | [0]" \
        --output text 2>/dev/null || true
    )"
    if [[ "${cluster_tag}" == "${CLUSTER_NAME}" ]]; then
      echo "    deleting ALB ${arn}"
      aws elbv2 delete-load-balancer --region "${AWS_REGION}" --load-balancer-arn "${arn}" || true
    fi
  done
}

delete_cluster_target_groups() {
  echo "==> target groups tagged for ${CLUSTER_NAME}"
  local arn cluster_tag
  for arn in $(
    aws elbv2 describe-target-groups --region "${AWS_REGION}" \
      --query 'TargetGroups[].TargetGroupArn' --output text 2>/dev/null || true
  ); do
    [[ -z "${arn}" || "${arn}" == "None" ]] && continue
    cluster_tag="$(
      aws elbv2 describe-tags --region "${AWS_REGION}" --resource-arns "${arn}" \
        --query "TagDescriptions[0].Tags[?Key=='elbv2.k8s.aws/cluster'].Value | [0]" \
        --output text 2>/dev/null || true
    )"
    if [[ "${cluster_tag}" == "${CLUSTER_NAME}" ]]; then
      echo "    deleting TG ${arn}"
      aws elbv2 delete-target-group --region "${AWS_REGION}" --target-group-arn "${arn}" || true
    fi
  done
}

vpc_id_for_name() {
  aws ec2 describe-vpcs --region "${AWS_REGION}" \
    --filters "Name=tag:Name,Values=${VPC_NAME}" \
    --query 'Vpcs[0].VpcId' --output text 2>/dev/null || true
}

delete_available_enis() {
  local vpc_id="$1"
  echo "==> available ENIs in ${vpc_id} (CNI leftovers look like aws-K8S-i-*)"
  local eni desc
  while read -r eni desc; do
    [[ -z "${eni}" || "${eni}" == "None" ]] && continue
    echo "    deleting ENI ${eni} (${desc})"
    aws ec2 delete-network-interface --region "${AWS_REGION}" --network-interface-id "${eni}" || true
  done < <(
    aws ec2 describe-network-interfaces --region "${AWS_REGION}" \
      --filters "Name=vpc-id,Values=${vpc_id}" "Name=status,Values=available" \
      --query 'NetworkInterfaces[].[NetworkInterfaceId,Description]' --output text 2>/dev/null || true
  )
}

delete_leftover_sgs() {
  local vpc_id="$1"
  echo "==> leftover security groups in ${vpc_id} (not default, not still in use)"
  local sg name
  while read -r sg name; do
    [[ -z "${sg}" || "${sg}" == "None" ]] && continue
    [[ "${name}" == "default" ]] && continue
    echo "    deleting SG ${sg} (${name})"
    aws ec2 delete-security-group --region "${AWS_REGION}" --group-id "${sg}" || true
  done < <(
    aws ec2 describe-security-groups --region "${AWS_REGION}" \
      --filters "Name=vpc-id,Values=${vpc_id}" \
      --query 'SecurityGroups[].[GroupId,GroupName]' --output text 2>/dev/null || true
  )
}

delete_ingresses_if_cluster_up
delete_cluster_albs
sleep 10
delete_cluster_target_groups

if cluster_active; then
  echo "==> cluster ${CLUSTER_NAME} is still up; skipping ENI/SG wipe"
  exit 0
fi

VPC_ID="$(vpc_id_for_name)"
if [[ -z "${VPC_ID}" || "${VPC_ID}" == "None" ]]; then
  echo "==> no VPC named ${VPC_NAME}; nothing else to clean"
  exit 0
fi

# ENIs first, then SGs (ENI holds the EKS default SG).
for _ in 1 2 3 4 5; do
  delete_available_enis "${VPC_ID}"
  sleep 5
done
delete_leftover_sgs "${VPC_ID}"

echo "==> leftovers pass done"
