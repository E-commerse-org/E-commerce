# --- 1. EKS Cluster IAM Role ---
resource "aws_iam_role" "eks_cluster" {
  name = "${var.cluster_name}-eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "eks.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster.name
}

# --- 3. EKS Node Group IAM Role ---
resource "aws_iam_role" "eks_nodes" {
  name = "${var.cluster_name}-eks-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eks_worker_node_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_nodes.name
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_nodes.name
}

resource "aws_iam_role_policy_attachment" "ec2_container_registry_read_only" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_nodes.name
}

# Attach AutoScalingFullAccess for Cluster Autoscaler
resource "aws_iam_role_policy_attachment" "eks_cluster_autoscaler_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AutoScalingFullAccess"
  role       = aws_iam_role.eks_nodes.name

  depends_on = [
    aws_iam_role.eks_nodes
  ]
}

# --- 4. EKS Cluster (Control Plane) ---
resource "aws_eks_cluster" "main" {
  name     = "${var.env}-${var.cluster_name}-${var.cell_name}"
  role_arn = aws_iam_role.eks_cluster.arn
  version  = var.kubernetes_version

  vpc_config {
    subnet_ids = concat(var.private_subnets, var.private_subnets_workaround)
  }

  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  depends_on = [aws_iam_role_policy_attachment.eks_cluster_policy]
}

# --- 5. EKS Managed Node Group ---
resource "aws_eks_node_group" "autoscaling_nodes" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "autoscaling-group"
  node_role_arn   = aws_iam_role.eks_nodes.arn
  subnet_ids      = var.private_subnets

  instance_types = [var.instance_type]
  ami_type        = "AL2_x86_64"
  
  remote_access {
    source_security_group_ids = []  # Allow control plane access
  }
  scaling_config {
    desired_size = var.desired_node_count
    min_size     = var.min_node_count
    max_size     = var.max_node_count
  }

  tags = {
    Name = "${var.cluster_name}-worker-node"
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.ec2_container_registry_read_only,
    aws_iam_role_policy_attachment.eks_cluster_autoscaler_policy,
  ]
}


