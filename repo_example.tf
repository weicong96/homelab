
variable "proxmox_username" {
  type = string
  sensitive = true
}

variable "proxmox_password" {
  type = string
  sensitive = true
}
variable "proxmox_api_url" {
  type = string
  sensitive = true
}
variable "proxmox_vm_user" {
  type = string
  sensitive = true
}
variable "proxmox_vm_password" {
  type = string
  sensitive = true
}
locals { 
    name = "TerraformedVM"
    target_node = "proxmox"
}


provider "proxmox" {
    pm_tls_insecure = true
    pm_api_url = var.proxmox_api_url
    pm_password = var.proxmox_password
    pm_user = var.proxmox_username
    pm_otp = ""
}
terraform {
  required_providers {
    proxmox = {
      source = "Telmate/proxmox"
      version = "3.0.2-rc05"
    }
  }
}

resource "proxmox_vm_qemu" "cloudinit-example" {
  vmid        = 108
  name        = "test-terraform0"
  target_node = "proxmox"
  agent       = 1
  cores       = 2
  memory      = 1024
  bios        = "seabios" # Legacy BIOS - matches the template's boot mode
  boot        = "order=scsi0" # has to be the same as the OS disk of the template
  bootdisk    = "scsi0" # Explicitly set boot disk
  clone       = "debian12-cloudinit" # The name of the template
  full_clone  = true # Ensure full clone to preserve boot partition
  scsihw      = "virtio-scsi-single"
  vm_state    = "running"
  automatic_reboot = true

  # Cloud-Init configuration
  cicustom   = "vendor=local:snippets/qemu-guest-agent.yml" # /var/lib/vz/snippets/qemu-guest-agent.yml
  ciupgrade  = true
  nameserver = "1.1.1.1 8.8.8.8"
  ipconfig0  = "ip=192.168.56.20/24,gw=192.168.56.1"
  skip_ipv6  = true
  ciuser     = var.proxmox_vm_user
  cipassword = var.proxmox_vm_password
  sshkeys    = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCYgucCr8+AyGmHhg4TI2Jrad9+j6g9D33ldioP7PZ7XIEGfzFMApMsnzjNtPYcipRROMZ2oNV2a6eCOoDDlhhb+GP9qsk9phAUigTmEK5ZjMTLhLL/k0WvHeBABpZJEUcrL/bkXK52iBxVmCn2VjP/PhaBztjgzLiOKJMdhcK+WYRS4cEBNBGAHfL+r8+WFe5XMyairo+7P8fkdQk5Lsb30T7UJCBelwLqg0E0TloXi9oo5ODoGQdCIZW5xhXMu2NyKjqJf0DfgL8AHMf61X9K05n8aZSGAAdYvYqI9bQN+b2l9q+fBu+x+prSQ4AeUOKiDjkd+/rdXYjv3h4G6J0j"

  # Most cloud-init images require a serial device for their display
  serial {
    id = 0
  }
  vga {
    type = "serial0" # Use serial console for cloud-init images
  }

  disks {
    scsi {
      scsi0 {
        # We have to specify the disk from our template, else Terraform will think it's not supposed to be there
        disk {
          storage = "local"
          # The size of the disk should be at least as big as the disk in the template. If it's smaller, the disk will be recreated
          # Most Debian cloud-init templates are 8GB+, so use at least 8G to preserve boot partition
          size    = "8G" 
        }
      }
    }
    ide {
      # Some images require a cloud-init disk on the IDE controller, others on the SCSI or SATA controller
      ide1 {
        cloudinit {
          storage = "local"
        }
      }
    }
  }

  network {
    id = 0
    bridge = "vmbr0"
    model  = "virtio"
  }
}