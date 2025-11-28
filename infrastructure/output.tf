output "eks_clusters" {
  description = "All EKS clusters for all cells"
  value = {
    for cell, mod in module.computes :
    cell => mod.cluster_info.name
  }
}


output "kubeconfig_commands" {
  description = "Kubeconfig commands for all EKS clusters"
  value = {
    for cell, mod in module.computes :
    cell => "aws eks update-kubeconfig --region ${var.region} --name ${mod.cluster_info.name}"
  }
}
