terraform {
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "0.7.6"
    }
  }
}

provider "libvirt" {
  uri = "qemu:///system"
}

variable "num_vms" { default = 4 }

resource "libvirt_volume" "base_volume" {
  name   = "base_volume"
  pool   = "default"
  source = "/home/faraouila2/Téléchargements/ubuntu-20.04-server-cloudimg-amd64.img"
  format = "qcow2"
}

resource "libvirt_volume" "volumes" {
  for_each = toset([for i in range(var.num_vms) : format("vm-%02d", i + 1)])
  name    = "${each.key}.${var.img_format}"
  pool    = "default"
  base_volume_id = libvirt_volume.base_volume.id
  size    = 10 * 1024 * 1024 * 1024 # 10 GB
  format  = var.img_format
}

resource "libvirt_network" "tf_network" {
  name      = "tf-network"
  mode      = "nat"
  autostart = "true"
  addresses = [var.vm_network]
  dhcp {
    enabled = true
  }  
  dns {
    enabled = true
  }
}

resource "libvirt_domain" "guest" {
  for_each = toset([for i in range(var.num_vms) : format("vm-%02d", i + 1)])
  name    = each.key
  memory  = var.mem_size
  vcpu    = var.cpu_cores

  disk {
    volume_id = libvirt_volume.volumes[each.key].id
  }

  network_interface {
    network_name    = libvirt_network.tf_network.name
#    wait_for_lease  = true
  }

  cloudinit = "${libvirt_cloudinit_disk.commoninit.id}"

  console {
    type        = "pty"
    target_type = "serial"
    target_port = "0"
  }

  graphics {
    type        = "spice"
    autoport    = true
    listen_type = "address"
  }
}

resource "libvirt_cloudinit_disk" "commoninit" {
  name           = "commoninit.iso"
  user_data      = data.template_file.user_data.rendered
  pool           = "default"
}

data "template_file" "user_data" {
  template = file("${path.module}/cloud_init.cfg")
  vars = {
    user_account = var.user_account
  }
}

output "node_info" {
  value = {
    for name, vm in libvirt_domain.guest : name => {
      name         = vm.name
      ip_address   = vm.network_interface[0].addresses[0]
    }
  }
}

variable "img_source" {
  description = "Ubuntu 22.04 LTS Cloud Image"
  default = "/home/faraouila2/Téléchargements/ubuntu-20.04-server-cloudimg-amd64.img"
}

variable "img_format" {
  description = "QCow2 UEFI/GPT Bootable disk image"
  default = "qcow2"
  type = string
}

variable "mem_size" {
  description = "Amount of RAM (in MiB) for the virtual machine"
  type        = string
  default     = "2048"
}

variable "cpu_cores" {
  description = "Number of CPU cores for the virtual machine"
  type        = number
  default     = 2
}

variable "vm_count" {
  description = "Number of virtual machines to create"
  type        = number
  default     = 4
}

variable "vm_network" {
  description = "Custom Network for my virtual machine names"
  default     = "192.168.100.0/24"
}

variable user_account {
  type = string
  default = "ubuntu"
}

