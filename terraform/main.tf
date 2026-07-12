resource "hcloud_ssh_key" "admin" {
  name       = "${var.name_prefix}-admin"
  public_key = var.ssh_public_key
}

resource "hcloud_firewall" "node" {
  name = "${var.name_prefix}-fw"

  # SSH — locked to the admin CIDR.
  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "22"
    source_ips = [var.admin_cidr]
  }

  # Kubernetes API — locked to the admin CIDR (ArgoCD runs in-cluster).
  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "6443"
    source_ips = [var.admin_cidr]
  }

  # HTTP/HTTPS — open to the world (Cloudflare proxies inbound traffic).
  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "80"
    source_ips = ["0.0.0.0/0", "::/0"]
  }
  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "443"
    source_ips = ["0.0.0.0/0", "::/0"]
  }
}

resource "hcloud_server" "node" {
  name        = "${var.name_prefix}-node"
  server_type = var.server_type
  image       = var.server_image
  location    = var.location

  ssh_keys     = [hcloud_ssh_key.admin.id]
  firewall_ids = [hcloud_firewall.node.id]

  public_net {
    ipv4_enabled = true
    ipv6_enabled = true
  }

  # The node reads its own public IP from Hetzner metadata at boot, so no
  # value is templated in here.
  user_data = templatefile("${path.module}/cloud-init.yaml.tftpl", {
    api_host = local.api_host
  })

  labels = {
    project = "loci"
    role    = "k3s-server"
  }
}
