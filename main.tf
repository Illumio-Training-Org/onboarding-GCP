terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

variable "gcp_project" {
  type = string
}

provider "google" {
  project = var.gcp_project
  region  = "europe-west2"
  zone    = "europe-west2-a"
}

resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "private_key" {
  content         = tls_private_key.ssh_key.private_key_pem
  filename        = "${path.module}/my-keypair.pem"
  file_permission = "0400"
}

resource "google_compute_instance" "vm" {
  name         = "simple-vm"
  machine_type = "e2-micro"
  zone         = "europe-west2-a"

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
    }
  }

  network_interface {
    network = "default"
    access_config {}
  }

  metadata = {
    ssh-keys = "debian:${tls_private_key.ssh_key.public_key_openssh}"
  }
}

output "public_ip" {
  value = google_compute_instance.vm.network_interface[0].access_config[0].nat_ip
}

output "ssh_command" {
  value = "ssh -i my-keypair.pem debian@${google_compute_instance.vm.network_interface[0].access_config[0].nat_ip}"
}
