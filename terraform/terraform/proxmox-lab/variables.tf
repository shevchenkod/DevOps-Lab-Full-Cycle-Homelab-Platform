# ── pve01 ──────────────────────────────────────────────
variable "pve01_endpoint" {
  type        = string
  description = "Proxmox API endpoint for pve01"
  default     = "https://10.44.81.101:8006"
}

variable "pve01_api_token" {
  type        = string
  sensitive   = true
  description = "API Token for pve01 (format: id=secret)"
}

# ── pve02 ──────────────────────────────────────────────
variable "pve02_endpoint" {
  type        = string
  description = "Proxmox API endpoint for pve02"
  default     = "https://10.44.81.102:8006"
}

variable "pve02_api_token" {
  type        = string
  sensitive   = true
  description = "API Token for pve02 (format: id=secret)"
}

# ── SSH & VM ────────────────────────────────────────────
variable "ssh_public_key_path" {
  type        = string
  description = "Path to SSH public key for cloud-init"
  default     = "H:/DEVOPS-LAB/ssh/devops-lab.pub"
}

variable "vm_password" {
  type      = string
  sensitive = true
  default   = "ubuntu"
}
