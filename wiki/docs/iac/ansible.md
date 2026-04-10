# �� Ansible

> **Agentless configuration management.** Describe the desired state — Ansible makes it happen.

## Lab Setup

- **Control node:** `k8s-master-01` (10.44.81.110) — Ansible core 2.16.3
- **Playbooks:** `~/ansible/` on master
- **Inventory:** `~/ansible/inventory.ini`
- **SSH key:** `~/.ssh/devops-lab` (ED25519)

```bash
# SSH to master from Windows workstation:
ssh -i "H:\DEVOPS-LAB\ssh\devops-lab" ubuntu@10.44.81.110
cd ~/ansible

# Ping all nodes
ansible -i inventory.ini k3s_cluster -m ping

# Run kubeadm bootstrap playbook
ansible-playbook -i inventory.ini kubeadm-cluster.yml
```

## Lab Files

| File | Purpose |
|------|---------|
| `~/ansible/inventory.ini` | Inventory for 3 nodes |
| `~/ansible/kubeadm-cluster.yml` | Baseline + kubeadm init + Calico + join workers |
| `H:\DEVOPS-LAB\ansible\kubeadm-cluster.yml` | Copy on workstation |

## Project Structure

```
ansible/
├── inventory/
│   ├── hosts.yaml
│   └── group_vars/
│       └── all.yaml
├── roles/
│   └── nginx/
│       ├── tasks/main.yaml
│       ├── templates/nginx.conf.j2
│       └── handlers/main.yaml
├── site.yaml
└── ansible.cfg
```

## Inventory Example

```yaml
all:
  children:
    webservers:
      hosts:
        web01:
          ansible_host: 192.168.1.101
        web02:
          ansible_host: 192.168.1.102
    databases:
      hosts:
        db01:
          ansible_host: 192.168.1.110
  vars:
    ansible_user: ubuntu
    ansible_ssh_private_key_file: ~/.ssh/id_rsa
```

## Playbook Template

```yaml
---
- name: Configure web servers
  hosts: webservers
  become: true

  tasks:
    - name: Install packages
      apt:
        name: [nginx, curl]
        state: present
        update_cache: true

    - name: Copy nginx config
      template:
        src: templates/nginx.conf.j2
        dest: /etc/nginx/sites-available/myapp
      notify: Reload nginx

  handlers:
    - name: Reload nginx
      service:
        name: nginx
        state: reloaded
```

## Key Commands

```bash
# Ping all hosts
ansible all -i inventory/hosts.yaml -m ping

# Run playbook
ansible-playbook -i inventory/hosts.yaml site.yaml

# Dry-run (check mode)
ansible-playbook -i inventory/hosts.yaml site.yaml --check

# Limit to specific hosts
ansible-playbook -i inventory/hosts.yaml site.yaml --limit web01

# Encrypt secrets with Vault
ansible-vault encrypt_string 'my-secret' --name 'db_password'
```
