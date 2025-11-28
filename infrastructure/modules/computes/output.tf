output "cluster_info" {
  description = "The name of the EKS cluster"
  value = {
    name     = aws_eks_cluster.main.name
    arn      = aws_eks_cluster.main.arn
    endpoint = aws_eks_cluster.main.endpoint
  }
}
output "aws_eks_node_group" {
  description = "The EKS Node Group"
  value       = aws_eks_node_group.autoscaling_nodes
}
output "node_group_name" {
  value = aws_eks_node_group.autoscaling_nodes.node_group_name
}
