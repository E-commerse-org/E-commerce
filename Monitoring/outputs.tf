output "grafana_url" {
  value = "http://$(kubectl get svc monitoring-grafana -n monitoring -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')"
}

output "grafana_admin_password" {
  value = "admin123" 
}
