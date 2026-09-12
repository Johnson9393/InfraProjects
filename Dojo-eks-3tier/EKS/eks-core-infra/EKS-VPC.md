# EKS Core Infrastructure — Theory & Concepts

This phase creates the **AWS foundation for the DevOps Dojo EKS application**. We keep this in a separate Terraform folder so the EKS platform and networking can be managed independently from the application infrastructure and Kubernetes deployment. The final outcome is a working VPC, subnets, NAT connectivity, EKS control plane, managed worker nodes, IAM permissions, and required EKS add-ons.

## VPC & Network

We use the public `terraform-aws-modules/vpc/aws` module instead of creating every VPC resource manually. The module creates and connects the required networking components such as the VPC, public/private subnets, route tables, internet gateway and NAT gateway.

The VPC uses:

    CIDR: 10.0.0.0/16

We created:

    Public Subnets
        → Used for public-facing AWS resources such as Load Balancers.

    Private Subnets
        → Used for EKS worker nodes and application workloads.

The EKS nodes are placed in the **private subnets**. This means the nodes do not need public IP addresses, while the NAT Gateway allows them to reach the internet when required for things such as pulling packages or making outbound connections.

We use multiple Availability Zones (`us-east-1a` and `us-east-1b`) so the cluster is not dependent on a single AZ. If one AZ has a problem, resources can continue running in another AZ.

### Kubernetes Subnet Tags

We added Kubernetes-related tags to the subnets because AWS needs to know which subnets Kubernetes is allowed to use for AWS Load Balancers.

For example:

    Public subnet
    → kubernetes.io/role/elb = 1

    Private subnet
    → kubernetes.io/role/internal-elb = 1

The idea is simple:

    Kubernetes creates a public LoadBalancer
            ↓
    AWS looks for subnets tagged for ELB
            ↓
    Uses the correct public subnets

For an internal LoadBalancer:

    Kubernetes creates internal LoadBalancer
            ↓
    AWS looks for internal-ELB tagged subnets
            ↓
    Uses the correct private subnets

So these tags do not create Load Balancers themselves. They tell AWS/Kubernetes **which subnets should be used when a Load Balancer is created later**.

## NAT Gateway

We use a NAT Gateway so resources inside the private subnets can make outbound internet connections without becoming directly reachable from the internet.

The basic flow is:

    Private EKS Node
          ↓
    NAT Gateway
          ↓
    Internet

The internet cannot directly initiate a connection back to the private node.

For this project we use a single NAT Gateway, which keeps the setup simpler and reduces cost. A production design may use NAT per AZ for higher availability.

## EKS Cluster

The `terraform-aws-modules/eks/aws` module creates the EKS cluster and manages the required AWS resources around it.

Our EKS cluster is:

    Name: dojo-eks
    Kubernetes Version: 1.34

The EKS control plane is managed by AWS. We are responsible mainly for the worker nodes and the Kubernetes workloads that run on them.

The cluster is connected to our VPC and private subnets, allowing Kubernetes workloads to communicate with the AWS networking environment.

We also enabled:

    enable_cluster_creator_admin_permissions = true

This gives the Terraform creator administrative access to the EKS cluster so we can initially manage it using `kubectl`.

## EKS Managed Node Group

We created an EKS Managed Node Group using:

    AMI: AL2023_x86_64_STANDARD
    Instance Type: m5.xlarge
    Desired: 2 nodes
    Minimum: 1 node
    Maximum: 5 nodes

These EC2 instances are the **worker nodes** where our Kubernetes Pods will actually run.

The flow is:

    EKS Control Plane
          ↓
    Managed Node Group
          ↓
    EC2 Worker Nodes
          ↓
    Kubernetes Pods
          ↓
    Frontend / Backend Containers

The nodes are managed by EKS, so AWS handles tasks such as node replacement and managed node-group lifecycle operations.

## Node IAM Role & ECR Access

The managed node group gets an IAM role. This role defines what the worker nodes are allowed to do in AWS.

We verified that the node role has:

    AmazonEKSWorkerNodePolicy
    AmazonEKS_CNI_Policy
    AmazonEC2ContainerRegistryReadOnly

The important ECR permission is:

    AmazonEC2ContainerRegistryReadOnly

This allows the worker nodes to pull private Docker images from ECR.

The application image flow will therefore be:

    GitHub Actions
          ↓
    Push image → ECR
          ↓
    EKS Pod needs image
          ↓
    Worker Node pulls image from ECR
          ↓
    Container starts

Because the ECR read-only policy already exists on the node role, we do not need to create another ECR pull policy for the nodes.

## EKS Add-ons

We enabled the standard EKS add-ons required by the cluster.

### CoreDNS

CoreDNS provides DNS inside the Kubernetes cluster.

It allows applications to find Kubernetes Services by name.

For example:

    Frontend Pod
         ↓
    backend-service:5000
         ↓
    CoreDNS
         ↓
    Backend Service
         ↓
    Backend Pod

This is what allows our frontend to communicate with the backend without using changing Pod IP addresses.

### VPC CNI

The AWS VPC CNI provides networking for Kubernetes Pods using the AWS VPC network.

It allows Pods to communicate using IP addresses from the VPC networking environment and communicate with AWS resources such as RDS when networking/security rules allow it.

In our application:

    Backend Pod
         ↓
    VPC networking
         ↓
    RDS

### kube-proxy

`kube-proxy` supports Kubernetes Service networking.

When the frontend connects to:

    backend-service:5000

the Kubernetes Service needs to forward that traffic to an available backend Pod. kube-proxy helps implement this Service networking on the nodes.

### EKS Pod Identity Agent

The EKS Pod Identity Agent allows Kubernetes Pods to receive AWS permissions through IAM roles when required.

This is useful when an application running inside a Pod needs to access AWS services without storing AWS access keys inside the container.

For example, later an application could use an IAM role to access:

    S3
    Secrets Manager
    SQS
    DynamoDB

without storing long-lived AWS credentials in the application.

## EKS Endpoint

We enabled:

    endpoint_public_access = true

This allows the Kubernetes API endpoint to be accessed through the public endpoint, subject to AWS/EKS access controls.

This makes it possible for us to configure `kubectl` from our local machine and manage the cluster.

## Overall Architecture

    AWS Account
         ↓
       VPC
         │
         ├── Public Subnets
         │      ↓
         │   Load Balancers
         │
         └── Private Subnets
                ↓
          EKS Worker Nodes
                ↓
          Kubernetes Pods
                ↓
        Frontend / Backend

    EKS Control Plane
          ↓
    Manages Kubernetes
          ↓
    Worker Nodes

    EKS Add-ons
          ↓
    CoreDNS
    VPC CNI
    kube-proxy
    Pod Identity Agent

## Final Outcome

After this phase, the AWS platform is ready for the application layer:

    VPC + Networking
          ↓
    Public/Private Subnets
          ↓
    NAT Connectivity
          ↓
    EKS Control Plane
          ↓
    Managed Worker Nodes
          ↓
    EKS Add-ons
          ↓
    Node IAM Role
          ↓
    ECR Pull Permission
          ↓
    Ready for Kubernetes Application Deployment

The important mental model is:

**Terraform creates the AWS/EKS foundation. EKS provides the Kubernetes platform. Worker nodes run our Pods. EKS add-ons provide networking, DNS, Service communication and AWS identity support. The next phase can therefore focus on deploying our frontend and backend application into this already-prepared EKS environment.**