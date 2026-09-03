# AWS Load Balancer Controller — IAM Policy

## 1. Purpose of the IAM Policy

The IAM Role answers:

    WHO can assume the role?

The IAM Policy answers:

    WHAT can the ALB Controller do after assuming the role?

The policy gives the AWS Load Balancer Controller the AWS permissions required to discover networking, create and manage ALB resources, configure security groups, and optionally integrate with services such as ACM, WAF, Shield, and Cognito.

---

## 2. Permission Block — Service-Linked Role

    Action:
    iam:CreateServiceLinkedRole

Purpose:

Allows the ALB Controller to create the AWS Service-Linked Role required by Elastic Load Balancing.

Restriction:

    Condition:
    iam:AWSServiceName = elasticloadbalancing.amazonaws.com

This means the controller can create a Service-Linked Role only for Elastic Load Balancing.

    Resource = "*"

Means this action is not restricted to one specific AWS resource ARN.

---

## 3. Permission Block — AWS Networking + ALB Discovery

This block contains permissions such as:

    ec2:Describe...
    elasticloadbalancing:Describe...

Purpose:

Allows the ALB Controller to inspect the AWS environment it needs to work with.

It can discover things such as:

    VPCs
    Subnets
    Availability Zones
    Security Groups
    Instances
    Network Interfaces
    Existing Load Balancers
    Listeners
    Target Groups
    Rules
    Target Health
    Tags

It also allows the controller to create, modify, and delete ALB routing rules:

    CreateRule
    ModifyRule
    DeleteRule

Simple meaning:

    "Let the ALB Controller understand the AWS networking
     and existing ALB setup and manage ALB routing rules."

---

## 4. Permission Block — ACM, WAF, Shield & Cognito

Permissions include:

    acm:ListCertificates
    acm:DescribeCertificate

    waf-regional:...
    wafv2:...

    shield:...

    cognito-idp:DescribeUserPoolClient

Purpose:

Allows the ALB Controller to integrate with optional AWS features used by an ALB.

Examples:

    ACM
    → Discover SSL/TLS certificates for HTTPS.

    WAF
    → Associate or remove AWS WAF protection from the ALB.

    Shield
    → Manage Shield protection when configured.

    Cognito
    → Read Cognito configuration when ALB authentication is used.

These permissions are mainly required when those features are configured.

---

## 5. Permission Block — Security Group Rules

Permissions:

    ec2:AuthorizeSecurityGroupIngress
    ec2:RevokeSecurityGroupIngress

Purpose:

Allows the ALB Controller to add or remove inbound rules in Security Groups.

Simple meaning:

    "Allow the controller to configure the Security Group
     required for the ALB."

---

## 6. Permission Block — Create Security Group

Permission:

    ec2:CreateSecurityGroup

Purpose:

Allows the ALB Controller to create a Security Group when required for the ALB.

---

## 7. Permission Block — Tag New Security Groups

Permission:

    ec2:CreateTags

Purpose:

Allows the controller to add AWS tags to newly created Security Groups.

The condition ensures this permission is associated with:

    CreateSecurityGroup

and includes the required region-related check.

Simple meaning:

    "Allow the controller to tag the Security Groups it creates."

---

## 8. Permission Block — Add / Remove Security Group Tags

Permissions:

    ec2:CreateTags
    ec2:DeleteTags

Purpose:

Allows the controller to manage tags on ALB-related Security Groups.

Simple meaning:

    "Allow the controller to maintain the tags
     on the Security Groups it manages."

---

## 9. Permission Block — Manage ALB Security Groups

Permissions:

    ec2:AuthorizeSecurityGroupIngress
    ec2:RevokeSecurityGroupIngress
    ec2:DeleteSecurityGroup

Purpose:

Allows the controller to manage the Security Groups associated with ALB resources.

The condition restricts these operations to resources identified with the ALB Controller's cluster tag:

    elbv2.k8s.aws/cluster

Simple meaning:

    "Allow the controller to modify or remove
     Security Groups belonging to its ALB resources."

---

## 10. Permission Block — Create ALB and Target Groups

Permissions:

    elasticloadbalancing:CreateLoadBalancer
    elasticloadbalancing:CreateTargetGroup

Purpose:

Allows the ALB Controller to create the main ALB infrastructure.

Simple meaning:

    "Allow the controller to create the ALB
     and its Target Groups."

---

## 11. Permission Block — Create and Delete Listeners & Rules

Permissions:

    elasticloadbalancing:CreateListener
    elasticloadbalancing:DeleteListener
    elasticloadbalancing:CreateRule
    elasticloadbalancing:DeleteRule

Purpose:

Allows the controller to configure ALB listeners and routing rules.

Simple meaning:

    "Allow the controller to configure
     how the ALB receives and routes traffic."

---

## 12. Permission Block — Tag ALB Resources

Permissions:

    elasticloadbalancing:AddTags
    elasticloadbalancing:RemoveTags

Purpose:

Allows the controller to add and remove AWS tags from:

    Load Balancers
    Target Groups
    Listeners
    Listener Rules

Simple meaning:

    "Allow the controller to maintain tags
     on the ALB resources it manages."

---

## 13. Permission Block — Modify and Delete ALB Resources

Permissions include:

    ModifyLoadBalancerAttributes
    SetIpAddressType
    SetSecurityGroups
    SetSubnets
    DeleteLoadBalancer
    ModifyTargetGroup
    ModifyTargetGroupAttributes
    DeleteTargetGroup

Purpose:

Allows the controller to modify or delete ALB infrastructure when the Kubernetes configuration changes or is removed.

Simple meaning:

    "Allow the controller to maintain the ALB infrastructure
     throughout its lifecycle."

---

## 14. Permission Block — Tag Newly Created ALB Resources

Permission:

    elasticloadbalancing:AddTags

Purpose:

Allows the controller to tag newly created Load Balancers and Target Groups.

The condition limits this to resources created through ALB creation actions such as:

    CreateTargetGroup
    CreateLoadBalancer

Simple meaning:

    "Allow the controller to tag the ALB resources
     when they are created."

---

## 15. Permission Block — Register / Deregister Targets

Permissions:

    elasticloadbalancing:RegisterTargets
    elasticloadbalancing:DeregisterTargets

Purpose:

Allows the ALB Controller to register Kubernetes application targets with Target Groups and remove them when they are no longer required.

Simple meaning:

    "Connect the ALB Target Group to the application targets
     and remove those targets when necessary."

---

# Overall Permission Picture

The entire policy gives the ALB Controller the ability to:

    1. Discover AWS networking
       ↓
       VPCs, Subnets, Security Groups, etc.

    2. Discover ALB resources
       ↓
       Load Balancers, Target Groups, Listeners, Rules, etc.

    3. Create ALB infrastructure
       ↓
       ALB + Target Groups + Listeners + Rules

    4. Configure networking
       ↓
       Security Groups + Subnets + networking rules

    5. Configure traffic routing
       ↓
       Listeners + Rules + Targets

    6. Maintain resources
       ↓
       Modify + Tag + Register/Deregister

    7. Delete resources when required
       ↓
       Load Balancers + Target Groups + Rules + Security Groups

    8. Integrate with optional AWS services
       ↓
       ACM + WAF + Shield + Cognito

## Easy Recall

    IAM Role / Trust Policy
    → WHO can use the ALB Controller role?

    IAM Policy
    → WHAT can the ALB Controller do?

    Overall IAM Policy purpose:

    "Give the ALB Controller the AWS permissions required
     to discover, create, configure, manage, and remove
     the AWS resources needed for Kubernetes Ingress."