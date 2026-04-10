locals {
  ssh_public_key = file(var.ssh_public_key_path)
}

# ── Master node (pve01) ────────────────────────────────
resource "proxmox_virtual_environment_vm" "k8s_master" {
  provider  = proxmox.pve01
  name      = "k8s-master-01"
  node_name = "pve01"
  vm_id     = 101

  clone {
    vm_id = 9000
    full  = true
  }

  cpu {
    cores = 2
    type  = "x86-64-v2-AES"
  }

  memory {
    dedicated = 4096
  }

  disk {
    datastore_id = "local-lvm"
    interface    = "scsi0"
    size         = 20
    discard      = "on"
  }

  network_device {
    bridge = "vmbr0"
    model  = "virtio"
  }

  operating_system {
    type = "l26"
  }

  initialization {
    ip_config {
      ipv4 {
        address = "10.44.81.110/24"
        gateway = "10.44.81.254"
      }
    }
    user_account {
      username = "ubuntu"
      password = var.vm_password
      keys     = [local.ssh_public_key]
    }
  }

  agent {
    enabled = true
  }

  tags = ["k8s", "master"]
}

# ── Worker-01 (pve01) ──────────────────────────────────
resource "proxmox_virtual_environment_vm" "k8s_worker_01" {
  provider  = proxmox.pve01
  name      = "k8s-worker-01"
  node_name = "pve01"
  vm_id     = 111

  clone {
    vm_id = 9000
    full  = true
  }

  cpu {
    cores = 4
    type  = "x86-64-v2-AES"
  }

  memory {
    dedicated = 6144
  }

  disk {
    datastore_id = "local-lvm"
    interface    = "scsi0"
    size         = 20
    discard      = "on"
  }

  network_device {
    bridge = "vmbr0"
    model  = "virtio"
  }

  operating_system {
    type = "l26"
  }

  initialization {
    ip_config {
      ipv4 {
        address = "10.44.81.111/24"
        gateway = "10.44.81.254"
      }
    }
    user_account {
      username = "ubuntu"
      password = var.vm_password
      keys     = [local.ssh_public_key]
    }
  }

  agent {
    enabled = true
  }

  tags = ["k8s", "worker"]
}

# ── Worker-02 (pve02) ──────────────────────────────────
resource "proxmox_virtual_environment_vm" "k8s_worker_02" {
  provider  = proxmox.pve02
  name      = "k8s-worker-02"
  node_name = "pve02"
  vm_id     = 112

  clone {
    vm_id = 9000
    full  = true
  }

  cpu {
    cores = 4
    type  = "x86-64-v2-AES"
  }

  memory {
    dedicated = 8192
  }

  disk {
    datastore_id = "local-lvm"
    interface    = "scsi0"
    size         = 20
    discard      = "on"
  }

  network_device {
    bridge = "vmbr0"
    model  = "virtio"
  }

  operating_system {
    type = "l26"
  }

  initialization {
    ip_config {
      ipv4 {
        address = "10.44.81.112/24"
        gateway = "10.44.81.254"
      }
    }
    user_account {
      username = "ubuntu"
      password = var.vm_password
      keys     = [local.ssh_public_key]
    }
  }

  agent {
    enabled = true
  }

  tags = ["k8s", "worker"]
}

# ── Worker-03 (pve02) ──────────────────────────────────
resource "proxmox_virtual_environment_vm" "k8s_worker_03" {
  provider  = proxmox.pve02
  name      = "k8s-worker-03"
  node_name = "pve02"
  vm_id     = 113

  clone {
    vm_id = 9000
    full  = true
  }

  cpu {
    cores = 4
    type  = "x86-64-v2-AES"
  }

  memory {
    dedicated = 8192
  }

  disk {
    datastore_id = "local-lvm"
    interface    = "scsi0"
    size         = 20
    discard      = "on"
  }

  network_device {
    bridge = "vmbr0"
    model  = "virtio"
  }

  operating_system {
    type = "l26"
  }

  initialization {
    ip_config {
      ipv4 {
        address = "10.44.81.113/24"
        gateway = "10.44.81.254"
      }
    }
    user_account {
      username = "ubuntu"
      password = var.vm_password
      keys     = [local.ssh_public_key]
    }
  }

  agent {
    enabled = true
  }

  tags = ["k8s", "worker"]
}
