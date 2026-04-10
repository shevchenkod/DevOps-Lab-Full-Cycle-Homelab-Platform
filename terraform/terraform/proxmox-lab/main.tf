provider "proxmox" {
  alias     = "pve01"
  endpoint  = var.pve01_endpoint
  api_token = var.pve01_api_token
  insecure  = true
}

provider "proxmox" {
  alias     = "pve02"
  endpoint  = var.pve02_endpoint
  api_token = var.pve02_api_token
  insecure  = true
}
