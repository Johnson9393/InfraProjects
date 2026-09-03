# Helm & AWS Load Balancer Controller

## 1. What is Helm?

Helm is a package manager for Kubernetes.

Instead of manually creating many Kubernetes YAML resources, Helm allows us to install a packaged application called a Helm Chart.

Simple comparison:

Linux:
    apt install <package>

Python:
    pip install <package>

Kubernetes:
    helm install <chart>

---

## 2. What is a Helm Chart?

A Helm Chart is a packaged collection of Kubernetes resources and configuration.

The AWS Load Balancer Controller provides its own Helm Chart.

The chart contains the Kubernetes resources required to install and run the controller.

So:

    Helm Repository
          ↓
    AWS Load Balancer Controller Chart
          ↓
    Helm installs it into EKS
          ↓
    ALB Controller runs as Kubernetes Pods

---

## 3. Why are we using the Terraform Helm Provider?

We want Terraform to manage the ALB Controller installation.

Therefore:

    Terraform
        ↓
    Helm Provider
        ↓
    Helm Chart
        ↓
    AWS Load Balancer Controller
        ↓
    EKS

The Helm provider allows Terraform to install and manage Helm releases.

---

## 4. Helm Release

We use:

    resource "helm_release" "aws_load_balancer_controller"

This tells Terraform:

    "Install and manage the AWS Load Balancer Controller
     as a Helm release."

A Helm Release is an installed instance of a Helm Chart.

---

## 5. Helm Repository

    repository = "https://aws.github.io/eks-charts"

This tells Helm where to download the AWS Helm Chart from.

In our case, it is the AWS EKS Helm Chart repository.

---

## 6. Chart

    chart = "aws-load-balancer-controller"

This tells Helm which chart we want from that repository.

So:

    AWS EKS Helm Repository
            ↓
    aws-load-balancer-controller
            ↓
    Install this chart

---

## 7. Release Name

    name = "aws-load-balancer-controller"

This is the name of the Helm release.

It identifies the installed ALB Controller release.

---

## 8. Namespace

    namespace = "kube-system"

This tells Helm to install the controller into the Kubernetes `kube-system` namespace.

So:

    EKS
      ↓
    kube-system
      ↓
    AWS Load Balancer Controller

---

## 9. Chart Version

    version = "1.11.0"

This specifies the Helm Chart version that we want to install.

It allows us to control exactly which chart version Terraform installs instead of automatically using whatever version happens to be latest.

---

# Helm `set` Values

The `set` section provides configuration values to the Helm Chart.

Think:

    "Install the chart with these specific settings."

---

## 10. Cluster Name

    {
      name  = "clusterName"
      value = var.cluster_name
    }

Tells the ALB Controller which EKS cluster it belongs to.

For our project:

    dojo-eks

---

## 11. AWS Region

    {
      name  = "region"
      value = var.region
    }

Tells the ALB Controller which AWS region it should work in.

For our project:

    us-east-1

---

## 12. VPC ID

    {
      name  = "vpcId"
      value = data.aws_vpc.main.id
    }

Tells the ALB Controller which VPC contains our EKS networking.

Example:

    vpc-0123456789abcdef

The VPC ID is obtained from the AWS VPC data source.

---

## 13. Create the ServiceAccount

    {
      name  = "serviceAccount.create"
      value = "true"
    }

Tells Helm:

    "Create the Kubernetes ServiceAccount for the ALB Controller."

The ServiceAccount will be:

    aws-load-balancer-controller

inside:

    kube-system

---

## 14. ServiceAccount Name

    {
      name  = "serviceAccount.name"
      value = "aws-load-balancer-controller"
    }

Specifies the exact name of the ServiceAccount.

So:

    Namespace:
    kube-system

    ServiceAccount:
    aws-load-balancer-controller

This is the Kubernetes identity used by the ALB Controller Pod.

---

## 15. Associate the IAM Role

    {
      name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
      value = aws_iam_role.aws_load_balancer_controller.arn
    }

This is the important connection between Kubernetes and AWS IAM.

It tells Kubernetes:

    "Associate this ServiceAccount with this IAM Role."

The IAM Role already has:

    Trust Policy
        ↓
    Who can assume the role?

and:

    IAM Policy
        ↓
    What AWS actions are allowed?

Therefore:

    ALB Controller Pod
          ↓
    Kubernetes ServiceAccount
          ↓
    IAM Role
          ↓
    IAM Policy
          ↓
    AWS permissions
          ↓
    Create / Manage ALB

The IAM Role is not attached directly to the Helm package.

It is associated with the Kubernetes ServiceAccount that the ALB Controller Pod uses.

---

## 16. Why `\\.` is used?

The actual Kubernetes annotation key is:

    eks.amazonaws.com/role-arn

The Helm `set` syntax treats `.` as a separator for nested values.

Because the annotation key itself contains dots, we escape them:

    eks\\.amazonaws\\.com/role-arn

Helm ultimately receives:

    eks.amazonaws.com/role-arn

This allows the IAM Role ARN to be stored as the ServiceAccount annotation.

---

## 17. `depends_on`

    depends_on = [
      aws_iam_role_policy_attachment.aws_load_balancer_controller
    ]

This tells Terraform:

    "Install the Helm Chart only after the IAM Policy
     has been attached to the ALB Controller IAM Role."

So Terraform creates things in this order:

    IAM Role
        ↓
    IAM Policy
        ↓
    Attach Policy to Role
        ↓
    Install Helm Chart
        ↓
    ALB Controller starts

This ensures the controller's AWS permissions are configured before the controller is installed.

---

# Complete Flow

    Terraform
        ↓
    Helm Provider
        ↓
    AWS EKS Helm Repository
        ↓
    ALB Controller Helm Chart
        ↓
    Install into kube-system
        ↓
    Create ServiceAccount
        ↓
    aws-load-balancer-controller
        ↓
    Associate IAM Role
        ↓
    IAM Role Trust Policy
        ↓
    EKS OIDC + STS
        ↓
    Temporary AWS credentials
        ↓
    IAM Policy
        ↓
    AWS ALB permissions
        ↓
    ALB Controller can create/manage ALBs

---

# Easy Recall

    Helm
    → Kubernetes package manager

    Helm Chart
    → Packaged Kubernetes application

    Helm Release
    → Installed instance of a Helm Chart

    Repository
    → Where Helm downloads the Chart from

    `set`
    → Configuration values passed to the Chart

    ServiceAccount
    → Kubernetes identity used by the ALB Controller Pod

    IAM Role annotation
    → Connects the Kubernetes ServiceAccount to the AWS IAM Role

    depends_on
    → Ensures IAM permissions are attached before installing the controller

## Main Purpose

The entire `helm_release` block does one main job:

    "Install the AWS Load Balancer Controller into EKS,
     configure it for our cluster/VPC/region,
     create its ServiceAccount,
     and associate that ServiceAccount with the IAM Role
     that gives it permission to manage AWS Load Balancers."