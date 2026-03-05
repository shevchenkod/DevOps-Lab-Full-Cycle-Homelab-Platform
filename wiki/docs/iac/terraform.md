# 🏗️ Terraform

> **Infrastructure as Code.** Describe in `.tf` files — get real resources.

## Project Structure

```
terraform/
├── environments/
│   ├── dev/
│   │   ├── main.tf
│   │   └── terraform.tfvars
│   └── prod/
│       └── main.tf
├── modules/
│   └── vm/
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
└── .terraform.lock.hcl
```

## Key Commands

```bash
terraform init                    # Download providers
terraform validate                # Check syntax
terraform fmt -recursive          # Format code
terraform plan                    # Show plan
terraform plan -out=tfplan        # Save plan to file
terraform apply tfplan            # Apply saved plan
terraform apply -auto-approve     # Apply without confirmation (CI/CD)
terraform destroy                 # Destroy resources
terraform state list              # List resources in state
terraform output                  # Show outputs
```

## Example — Proxmox VM

```hcl
terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.50"
    }
  }
}

provider "proxmox" {
  endpoint = var.proxmox_endpoint
  username = var.proxmox_user
  password = var.proxmox_password
  insecure = true
}

resource "proxmox_virtual_environment_vm" "k8s_node" {
  count     = var.vm_count
  name      = "k8s-worker-${count.index + 1}"
  node_name = "pve"
  tags      = ["kubernetes", "worker"]

  cpu {
    cores = 4
    type  = "host"
  }

  memory {
    dedicated = 8192
  }

  disk {
    datastore_id = "local-lvm"
    size         = 50
    interface    = "virtio0"
  }

  clone {
    vm_id = 9000
    full  = true
  }
}

output "vm_ips" {
  value = proxmox_virtual_environment_vm.k8s_node[*].ipv4_addresses
}
```

## Remote State Backend (MinIO/S3)

Terraform state is stored in MinIO (S3-compatible) for team collaboration and CI/CD:

```hcl
terraform {
  backend "s3" {
    bucket   = "terraform-state"
    key      = "prod/terraform.tfstate"
    region   = "us-east-1"
    endpoint = "http://minio.example.com"
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    force_path_style            = true
  }
}
```

!!! tip "Secrets"
    All credentials are passed via `TF_VAR_*` environment variables — never hardcoded in `.tf` files.
    Use `.tfvars` files locally and add them to `.gitignore`.
