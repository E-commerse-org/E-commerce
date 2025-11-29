# EKS Multi-Cell Infrastructure Documentation

## Overview

This Terraform infrastructure provisions a highly available, multi-cell Amazon EKS (Elastic Kubernetes Service) architecture on AWS. The design implements a cell-based pattern with three independent EKS clusters (cell1, cell2, cell3) for improved fault isolation and scalability.

## Architecture Components
![Architecture](Architecture.png)
---
### Core Infrastructure

- **VPC**: Custom VPC with configurable CIDR block
- **Subnets**: 
  - 3 Public subnets (one per availability zone)
  - 6 Private subnets (two per availability zone, distributed across cells)
- **EKS Clusters**: 3 independent clusters (cell1, cell2, cell3)
- **Load Balancing**: AWS Load Balancer Controller for each cluster
- **Auto Scaling**: Cluster Autoscaler for dynamic node scaling
- **VPC Endpoints**: Private endpoints for ECR, S3, and CloudWatch Logs

## Directory Structure

```
infrastructure/
├── main.tf                          # Root module - VPC, networking, compute orchestration
├── variable.tf                      # Root-level variables
├── output.tf                        # Root-level outputs
├── provider.tf                      # Provider configurations (AWS, Kubernetes, Helm)
├── terraform-dev.tfvars            # Development environment variables
├── terraform-prod.tfvars           # Production environment variables
├── iam_policy.json                 # IAM policy for AWS Load Balancer Controller
├── aws_lb_controller_policy.json   # Duplicate LB controller policy
├── nlb-service.yaml                # Sample NLB service configuration
├── ns.json                         # Namespace configuration example
├── .gitignore                      # Terraform ignore rules
├── .terraform.lock.hcl             # Provider version lock file
│
└── modules/
    ├── network/                    # Network module
    │   ├── main.tf                # Subnets, IGW, NAT, VPC endpoints
    │   ├── variable.tf            # Network variables
    │   └── output.tf              # Network outputs
    │
    ├── computes/                   # EKS cluster module
    │   ├── main.tf                # EKS cluster and node group
    │   ├── variable.tf            # Compute variables
    │   └── output.tf              # Cluster outputs
    │
    └── eks-addons/                 # EKS add-ons module
        ├── main.tf                # LB controller, Cluster Autoscaler
        ├── variable.tf            # Add-on variables
        └── output.tf              # Add-on outputs
```

## Prerequisites

### Required Tools

- Terraform >= 1.0
- AWS CLI configured with appropriate credentials
- kubectl (for cluster management)
- Helm (for chart deployments)

### AWS Provider Versions

- AWS Provider: ~> 5.0
- Kubernetes Provider: 2.38.0
- Helm Provider: ~> 2.12
- Local Provider: 2.6.1

### Required AWS Permissions

The AWS user/role must have permissions for:
- VPC and networking resources
- EKS cluster management
- IAM role and policy management
- EC2 instances and Auto Scaling
- Elastic Load Balancing
- ECR, S3, CloudWatch access

## Configuration

### Environment Variables

#### Development Environment (`terraform-dev.tfvars`)

```hcl
region             = "us-east-1"
environment        = "dev"
associated_project = "myapp"
cidr_block         = "10.0.0.0/16"
az                 = ["us-east-1a", "us-east-1b", "us-east-1c"]
ecr_name           = "dev-myapp"

# EKS Configuration
eks_version         = "1.31"
node_instance_types = ["t3.medium"]
min_nodes           = 1
max_nodes           = 3
desired_nodes       = 2

# DocumentDB Configuration
docdb_master_username = "admin"
docdb_master_password = "YourSecurePassword123!"
docdb_instance_class  = "db.t3.medium"

# Redis Configuration
redis_node_type = "cache.t3.micro"
```

#### Production Environment (`terraform-prod.tfvars`)

```hcl
environment        = "prod"
cidr_block         = "10.0.0.0/16"
az                 = ["us-east-1a", "us-east-1b", "us-east-1c"]
associated_project = "e-commerce"
container_port     = 80
cpu                = 1024
memory             = 2048
```

### Key Configuration Parameters

| Variable | Description | Default |
|----------|-------------|---------|
| `region` | AWS region for deployment | `us-east-1` |
| `environment` | Environment name (dev/prod) | `dev` |
| `cidr_block` | VPC CIDR block | Required |
| `az` | List of availability zones | Required |
| `min_node_count` | Minimum nodes per cluster | `1` |
| `max_node_count` | Maximum nodes per cluster | `3` |
| `desired_node_count` | Desired nodes per cluster | `1` |

## Network Architecture

### Subnet Design

#### Public Subnets (3 total)
- CIDR: Calculated using `cidrsubnet(vpc_cidr, 4, count.index)`
- One per availability zone
- Internet-facing via Internet Gateway
- Used for NAT Gateways and public load balancers

#### Private Subnets (6 total)
- CIDR: Calculated using `cidrsubnet(vpc_cidr, 4, count.index + 3)`
- Two per availability zone (distributed across cells)
- Internet access via NAT Gateway
- Host EKS worker nodes

### Cell-to-Subnet Mapping

```hcl
cell_private_subnet_map = {
  cell1 = 0  # private_subnet[0]
  cell2 = 2  # private_subnet[2]
  cell3 = 4  # private_subnet[4]
}

cell_private_subnet_workround_map = {
  cell1 = 4  # private_subnet[4]
  cell2 = 0  # private_subnet[0]
  cell3 = 2  # private_subnet[2]
}

cell_public_subnet_map = {
  cell1 = 0  # public_subnet[0]
  cell2 = 1  # public_subnet[1]
  cell3 = 2  # public_subnet[2]
}
```

### VPC Endpoints

The infrastructure provisions private VPC endpoints for:

1. **ECR DKR** (Interface): Docker image layer access
2. **ECR API** (Interface): ECR API operations
3. **S3** (Gateway): S3 bucket access
4. **CloudWatch Logs** (Interface): Log streaming

All interface endpoints use private DNS and are secured by the VPC endpoints security group.

## Security Groups

### VPC Endpoints Security Group
- **Ingress**: Port 443 from ECS security group
- **Ingress**: Container port from anywhere (0.0.0.0/0)
- **Egress**: All traffic

### ECS Security Group
- **Ingress**: Container port from ALB security group
- **Ingress**: Port 443 from ALB security group
- **Egress**: All traffic

### ALB Security Group
- **Ingress**: Port 443 from anywhere (0.0.0.0/0)
- **Ingress**: Container port from anywhere (0.0.0.0/0)
- **Egress**: All traffic

### RDS Security Group
- **Ingress**: Port 5432 (PostgreSQL) from ECS security group
- **Egress**: All traffic

## EKS Cluster Configuration

### Cluster Components

Each of the three cells provisions:

1. **EKS Control Plane**
   - Kubernetes version: 1.29 (default, configurable)
   - Managed by AWS
   - Enabled logging: API, Audit, Authenticator, Controller Manager, Scheduler

2. **Managed Node Group**
   - Instance type: t3.micro (default, configurable)
   - AMI type: AL2_x86_64
   - Scaling configuration:
     - Min: 1 node
     - Desired: 1 node
     - Max: 3 nodes

3. **IAM Roles**
   - Cluster role with AmazonEKSClusterPolicy
   - Node role with:
     - AmazonEKSWorkerNodePolicy
     - AmazonEKS_CNI_Policy
     - AmazonEC2ContainerRegistryReadOnly
     - AutoScalingFullAccess

### Cluster Naming Convention

```
{environment}-cluster-{environment}-{cell_name}-{cell_name}
```

Example: `dev-cluster-dev-cell1-cell1`

## EKS Add-ons

### AWS Load Balancer Controller

Automatically provisions and manages AWS Application Load Balancers (ALB) and Network Load Balancers (NLB) for Kubernetes services and ingresses.

**Installation per cluster:**
- Deployed via Helm chart from AWS EKS Charts repository
- Service account with IRSA (IAM Roles for Service Accounts)
- Namespace: `kube-system`

**IAM Policy:** Includes permissions for:
- Creating/managing load balancers
- Managing target groups
- Security group operations
- ACM certificate operations
- WAF integration

### Cluster Autoscaler

Automatically adjusts the number of nodes in the cluster based on pod resource requests.

**Configuration:**
- Image: `k8s.gcr.io/autoscaling/cluster-autoscaler:v1.27.1`
- Deployment: Single replica in `kube-system` namespace
- Resources:
  - CPU: 100m (request & limit)
  - Memory: 300Mi (request & limit)
- Scaling parameters passed via node group name reference

**Command-line flags:**
```
--cloud-provider=aws
--skip-nodes-with-local-storage=false
--balance-similar-node-groups
--expander=least-waste
--nodes={min}:{max}:{node_group_name}
```

## Deployment Instructions

### Initial Setup

1. **Configure Backend**

The infrastructure uses S3 backend for state management:

```hcl
backend "s3" {
  bucket  = "depi-terraform-state-file"
  key     = "terraform.tfstate"
  region  = "us-east-1"
  encrypt = true
}
```

Ensure the S3 bucket exists before deployment.

2. **Initialize Terraform**

```bash
cd infrastructure
terraform init
```

3. **Review Plan**

For development:
```bash
terraform plan -var-file="terraform-dev.tfvars"
```

For production:
```bash
terraform plan -var-file="terraform-prod.tfvars"
```

4. **Apply Configuration**

```bash
terraform apply -var-file="terraform-dev.tfvars"
```

### Post-Deployment

After successful deployment, configure kubectl for each cluster:

```bash
# Cell 1
aws eks update-kubeconfig --region us-east-1 --name dev-cluster-dev-cell1-cell1

# Cell 2
aws eks update-kubeconfig --region us-east-1 --name dev-cluster-dev-cell2-cell2

# Cell 3
aws eks update-kubeconfig --region us-east-1 --name dev-cluster-dev-cell3-cell3
```

Verify cluster connectivity:

```bash
kubectl get nodes
kubectl get pods -n kube-system
```

## Outputs

The infrastructure provides the following outputs:

### `eks_clusters`
Map of cell names to EKS cluster names:
```hcl
{
  cell1 = "dev-cluster-dev-cell1-cell1"
  cell2 = "dev-cluster-dev-cell2-cell2"
  cell3 = "dev-cluster-dev-cell3-cell3"
}
```

### `kubeconfig_commands`
Ready-to-use commands for configuring kubectl:
```hcl
{
  cell1 = "aws eks update-kubeconfig --region us-east-1 --name dev-cluster-dev-cell1-cell1"
  cell2 = "aws eks update-kubeconfig --region us-east-1 --name dev-cluster-dev-cell2-cell2"
  cell3 = "aws eks update-kubeconfig --region us-east-1 --name dev-cluster-dev-cell3-cell3"
}
```

## Deploying Applications

### Using Network Load Balancer

Example service configuration (`nlb-service.yaml`):

```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-nlb-service
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-type: "nlb"
    service.beta.kubernetes.io/aws-load-balancer-nlb-target-type: "ip"
    service.beta.kubernetes.io/aws-load-balancer-scheme: "internet-facing"
    service.beta.kubernetes.io/aws-load-balancer-cross-zone-load-balancing-enabled: "false"
spec:
  type: LoadBalancer
  ports:
    - name: http
      port: 5000
      targetPort: 5000
      protocol: TCP
  selector:
    app: my-app
```

Deploy:
```bash
kubectl apply -f nlb-service.yaml
```

### Kubernetes Tags

The subnets are pre-tagged for Kubernetes integration:

**Public Subnets:**
```hcl
"kubernetes.io/cluster/cluster-{env}-cell1" = "owned"
"kubernetes.io/cluster/cluster-{env}-cell2" = "owned"
"kubernetes.io/cluster/cluster-{env}-cell3" = "owned"
"kubernetes.io/role/internal-elb" = "1"
```

**Private Subnets:**
```hcl
"kubernetes.io/cluster/cluster-{env}-cell1" = "owned"
"kubernetes.io/cluster/cluster-{env}-cell2" = "owned"
"kubernetes.io/cluster/cluster-{env}-cell3" = "owned"
```

## Cost Optimization

### Resource Sizing

**Development Environment:**
- Node instance type: `t3.micro` (default)
- Min nodes: 1 per cluster
- 3 NAT Gateways (one per AZ)

**Production Environment:**
- Node instance type: `t3.medium` (recommended)
- Min nodes: 2+ per cluster for HA
- Consider NAT Gateway consolidation

### Recommendations

1. **Use Spot Instances**: Modify node group to use spot instances for non-critical workloads
2. **Right-size Nodes**: Monitor actual resource usage and adjust instance types
3. **Optimize NAT**: Consider using a single NAT Gateway for dev environments
4. **Reserved Instances**: Purchase RIs for production EKS clusters
5. **Auto Scaling**: Leverage Cluster Autoscaler to scale down during low usage

## Maintenance & Operations

### Updating Kubernetes Version

1. Update the `kubernetes_version` variable in your tfvars file
2. Run `terraform plan` to review changes
3. Apply changes: `terraform apply`
4. Update `kubectl` and verify compatibility

### Scaling Nodes

Modify variables in tfvars:
```hcl
min_node_count     = 2
desired_node_count = 3
max_node_count     = 5
```

Apply changes:
```bash
terraform apply -var-file="terraform-dev.tfvars"
```

### Monitoring

**CloudWatch Logs**: All EKS control plane logs are enabled:
- API server logs
- Audit logs
- Authenticator logs
- Controller manager logs
- Scheduler logs

Access logs in CloudWatch Log Groups:
```
/aws/eks/{cluster-name}/cluster
```

### Troubleshooting

#### Namespace Stuck in Terminating State

The provided `ns.json` shows an example of a namespace stuck terminating. To resolve:

```bash
kubectl get namespace nginx-app -o json > temp.json
# Edit temp.json and remove finalizers
kubectl replace --raw "/api/v1/namespaces/nginx-app/finalize" -f ./temp.json
```

#### Node Group Not Scaling

1. Check Cluster Autoscaler logs:
```bash
kubectl logs -n kube-system deployment/cluster-autoscaler
```

2. Verify IAM permissions for AutoScalingFullAccess

3. Check node group configuration:
```bash
aws eks describe-nodegroup --cluster-name {cluster-name} --nodegroup-name autoscaling-group
```

## Security Best Practices

1. **Secrets Management**: Use AWS Secrets Manager or Parameter Store for sensitive data (DB passwords, API keys)
2. **Network Policies**: Implement Kubernetes Network Policies for pod-to-pod communication
3. **RBAC**: Configure Role-Based Access Control for cluster access
4. **Pod Security**: Enable Pod Security Standards (PSS)
5. **Image Scanning**: Enable ECR image scanning for vulnerabilities
6. **Private Endpoints**: All EKS API endpoints should use private access for production
7. **Encryption**: Enable encryption at rest for EBS volumes and secrets

## Known Limitations

1. **Provider Configuration**: The infrastructure uses aliased providers per cell, which may cause issues with provider configuration during initial deployment
2. **Duplicate IAM Roles**: The `eks-addons` module creates duplicate IAM roles that already exist in the `computes` module
3. **Circular Dependencies**: Some resources may experience timing issues during initial deployment
4. **State File**: Single state file manages all three cells; consider separate state files per cell for production

## Future Improvements

1. **Modularize Provider Configuration**: Use dynamic provider configuration
2. **Implement GitOps**: Add Flux or ArgoCD for application deployment
3. **Service Mesh**: Consider Istio or AWS App Mesh for advanced traffic management
4. **Observability Stack**: Deploy Prometheus, Grafana, and EFK stack
5. **Backup Strategy**: Implement Velero for cluster backup and disaster recovery
6. **Multi-Region**: Extend architecture for multi-region deployment
7. **Policy Enforcement**: Add OPA Gatekeeper for policy enforcement

## References

- [AWS EKS Documentation](https://docs.aws.amazon.com/eks/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [AWS Load Balancer Controller](https://kubernetes-sigs.github.io/aws-load-balancer-controller/)
- [Cluster Autoscaler](https://github.com/kubernetes/autoscaler/tree/master/cluster-autoscaler)

## Support & Contributing

For issues or questions:
1. Review CloudWatch logs for cluster issues
2. Check Terraform plan output for configuration errors
3. Verify AWS service limits and quotas
4. Review security group rules and network connectivity

---

**Version**: 2.0  
**Last Updated**: November 2025  
**Maintained By**: Infrastructure Team
