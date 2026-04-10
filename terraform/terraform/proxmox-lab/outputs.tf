output "k8s_master_ip" {
  value = "10.44.81.110"
}

output "k8s_worker_ips" {
  value = ["10.44.81.111", "10.44.81.112", "10.44.81.113"]
}

output "ssh_command_master" {
  value = "ssh -i H:/DEVOPS-LAB/ssh/devops-lab ubuntu@10.44.81.110"
}
