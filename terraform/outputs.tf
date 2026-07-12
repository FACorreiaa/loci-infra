output "node_ipv4" {
  description = "Public IPv4 of the k3s node."
  value       = hcloud_server.node.ipv4_address
}

output "app_host" {
  description = "Web app hostname."
  value       = local.app_host
}

output "api_host" {
  description = "API + MCP hostname."
  value       = local.api_host
}

output "argocd_host" {
  description = "ArgoCD UI hostname."
  value       = local.argocd_host
}

output "kubeconfig_hint" {
  description = "How to fetch the kubeconfig once the node is up."
  value       = "ssh root@${hcloud_server.node.ipv4_address} 'cat /etc/rancher/k3s/k3s.yaml' | sed 's#127.0.0.1#${hcloud_server.node.ipv4_address}#' > kubeconfig.yaml"
}
