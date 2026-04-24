terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
  }
}

###############################
# Variables
###############################

variable "gcp_project" {
  type = string
}

variable "gcp_zone" {
  default = "europe-west2-a"
}

###############################
# Provider (NO REGION)
###############################

provider "google" {
  project = var.gcp_project
  zone    = var.gcp_zone
}

###############################
# SSH Key
###############################

resource "tls_private_key" "ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "private_key" {
  content         = tls_private_key.ssh.private_key_pem
  filename        = "${path.module}/id_rsa"
  file_permission = "0400"
}

###############################
# VM (Default VPC only)
###############################

resource "google_compute_instance" "vm" {
  name         = "simple-vm"
  machine_type = "e2-micro"
  zone         = var.gcp_zone

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
    }
  }

  network_interface {
    network = "default"
    access_config {} # public IP
  }

  metadata = {
    ssh-keys = "debian:${tls_private_key.ssh.public_key_openssh}"
  }
}

###############################
# Outputs
###############################

output "public_ip" {
  value = google_compute_instance.vm.network_interface[0].access_config[0].nat_ip
}

output "ssh_command" {
  value = "ssh -i id_rsa debian@${google_compute_instance.vm.network_interface[0].access_config[0].nat_ip}"
}
