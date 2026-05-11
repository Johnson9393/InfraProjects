# SSM and OIDC Concepts in Real Projects

## SSM Level Permission Concepts

Let’s say we have Development and QA teams working on applications hosted inside private EC2 instances.

In real-world organizations, developers and QA engineers usually do not receive direct SSM or server-level access to production or private instances. Instead, they access the application through environment-level endpoints such as:

* Load Balancers
* Internal URLs
* VPN-connected applications
* Internal dashboards

This improves security and reduces unnecessary infrastructure access.

If server access is required for troubleshooting or debugging purposes, organizations provide controlled SSM access by attaching specific IAM permissions to the users or roles.

Example:

```text
ssm:StartSession
ssm:SendCommand
```

Access is usually restricted based on:

* Environment
* Team
* EC2 tags
* Specific instances

---

# Admin Level Access

Admin or DevOps roles generally have permissions to connect to EC2 instances through AWS Systems Manager (SSM).

Since SSM works using IAM authentication and outbound communication from EC2 instances, there is no need for:

* SSH keys
* Bastion hosts
* Public IPs
* Port 22 access

---

# VPN Concepts with SSM

Many enterprise organizations use VPN connections for additional security.

VPN creates a secure network tunnel between the user device and the organization’s internal network.

Usually companies ask employees to install:

* VPN clients
* Hardware authentication tools
* Corporate security agents

before accessing internal infrastructure.

In such environments, organizations may enforce policies where only VPN-connected users are allowed to access AWS resources or initiate SSM sessions.

These restrictions are commonly enforced using:

* IAM policies
* IAM conditions
* SSO policies
* SCPs (Service Control Policies)
* Source IP restrictions
* Private VPC endpoints

rather than traditional Security Group inbound rules.

A common enterprise architecture looks like:

```text
Laptop
   ↓
VPN Connection
   ↓
Corporate SSO Authentication
   ↓
AWS IAM Role
   ↓
SSM Session
   ↓
Private EC2 Instance
```

---

# CI/CD Pipeline Authentication - Old Approach

Earlier, CI/CD tools such as:

* Jenkins
* GitHub Actions
* GitLab CI

used long-lived IAM user credentials.

Example:

```text
AWS Access Key
AWS Secret Key
```

These credentials were stored inside:

* Jenkins credentials
* GitHub secrets
* Environment variables

Problems with this approach:

* Long-lived credentials
* Secret leakage risks
* Difficult credential rotation
* Higher security exposure

---

# Modern Approach - OIDC Authentication

Modern CI/CD pipelines use OIDC (OpenID Connect) federation.

OIDC creates a trust relationship between:

* GitHub Actions
* Jenkins
* Kubernetes Service Accounts
* Other machine identities

and AWS IAM roles.

Instead of storing permanent AWS credentials, the CI/CD platform requests temporary AWS credentials dynamically.

Flow:

```text
GitHub Actions
    ↓
OIDC Token
    ↓
AWS IAM OIDC Provider
    ↓
Assume IAM Role
    ↓
Temporary STS Credentials
```

With OIDC:

* No long-lived AWS secrets are stored
* Authentication becomes short-lived and secure
* Access is centrally controlled using IAM roles

The CI/CD pipeline receives only the permissions assigned to the IAM role.

Example permissions:

* Terraform deployments
* EC2 access
* S3 backend access
* EKS deployments
* SSM command execution

Organizations usually follow the Principle of Least Privilege, meaning pipelines receive only the permissions required for their tasks rather than full administrator access.

---

# Final Understanding

SSM, VPN, IAM, and OIDC together form a modern secure enterprise infrastructure management approach.

Key concepts:

* SSM replaces SSH and bastion-based access
* VPN secures corporate network access
* IAM controls permissions
* OIDC replaces long-lived AWS credentials
* CI/CD pipelines use temporary authentication
* Enterprise environments heavily rely on role-based secure access
