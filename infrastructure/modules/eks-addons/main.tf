# --- Create IAM Policy ---
resource "aws_iam_policy" "aws_lb_controller_policy" {
  name        = "${var.cluster_name}-AWSLoadBalancerControllerPolicy"
  description = "IAM policy for AWS Load Balancer Controller"

  policy = file("aws_lb_controller_policy.json")
}

# --- Create IAM Role for the Controller ---
resource "aws_iam_role" "aws_lb_controller_role" {
  name = "${var.cluster_name}-aws-lb-controller"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "eks.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# --- Attach the Policy to the Role ---
resource "aws_iam_role_policy_attachment" "aws_lb_controller_attach" {
  role       = aws_iam_role.aws_lb_controller_role.name
  policy_arn = aws_iam_policy.aws_lb_controller_policy.arn
}

# --- Kubernetes Service Account ---
resource "kubernetes_service_account" "aws_lb_controller" {
  metadata {
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.aws_lb_controller_role.arn
    }
  }
}

# --- Install AWS LB Controller via Helm ---
resource "helm_release" "aws_lb_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"

  set {
    name  = "clusterName"
    value = var.cluster_name
  }

  set {
    name  = "region"
    value = var.cluster_region
  }

  set {
    name  = "vpcId"
    value = var.vpc_id
  }

  set {
    name  = "serviceAccount.create"
    value = "false"
  }

  set {
    name  = "serviceAccount.name"
    value = kubernetes_service_account.aws_lb_controller.metadata[0].name
  }

  depends_on = [
    kubernetes_service_account.aws_lb_controller,
    aws_iam_role_policy_attachment.aws_lb_controller_attach
  ]
}

resource "local_file" "kubeconfig_wait" {
  depends_on = [var.node_group_name]
  filename   = "kubeconfig_ready.txt"
  content    = "EKS cluster and node group are ready."
}

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

# --- 7. Cluster Autoscaler ---
resource "kubernetes_service_account" "cluster_autoscaler" {
  metadata {
    name      = "cluster-autoscaler"
    namespace = "kube-system"
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.eks_nodes.arn
    }
  }
}

resource "kubernetes_deployment" "cluster_autoscaler" {
  metadata {
    name      = "cluster-autoscaler"
    namespace = "kube-system"
    labels = {
      app = "cluster-autoscaler"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "cluster-autoscaler"
      }
    }

    template {
      metadata {
        labels = {
          app = "cluster-autoscaler"
        }
      }

      spec {
        service_account_name = kubernetes_service_account.cluster_autoscaler.metadata[0].name

        container {
          name  = "cluster-autoscaler"
          image = "k8s.gcr.io/autoscaling/cluster-autoscaler:v1.27.1"

          command = [
            "./cluster-autoscaler",
            "--v=4",
            "--cloud-provider=aws",
            "--skip-nodes-with-local-storage=false",
            "--balance-similar-node-groups",
            "--expander=least-waste",
            "--nodes=${var.min_node_count}:${var.max_node_count}:${var.node_group_name}"
          ]

          resources {
            limits = {
              cpu    = "100m"
              memory = "300Mi"
            }
            requests = {
              cpu    = "100m"
              memory = "300Mi"
            }
          }

          env {
            name  = "AWS_REGION"
            value = var.cluster_region
          }
        }
      }
    }
  }
}

# ============================
