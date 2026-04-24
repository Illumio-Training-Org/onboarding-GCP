terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

###############################
# Variables
###############################

variable "gcp_project" {
  description = "GCP project ID"
  type        = string
}

variable "gcp_region" {
  default = "europe-west2"
}

variable "gcp_zone" {
  default = "europe-west2-a"
}

variable "machine_type" {
  default = "e2-micro"
}

variable "image_family" {
  default = "debian-11"
}

variable "image_project" {
  default = "debian-cloud"
}

###############################
# Provider
###############################

provider "google" {
  project = var.gcp_project
  region  = var.gcp_region
  zone    = var.gcp_zone
}

###############################
# Network (minimal custom VPC)
###############################

resource "google_compute_network" "main" {
  name                    = "dev-vpc"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "main" {
  name          = "dev-subnet"
  ip_cidr_range = "10.0.1.0/24"
  region        = var.gcp_region
  network       = google_compute_network.main.id
}

###############################
# Firewall (SSH)
###############################

resource "google_compute_firewall" "ssh" {
  name    = "allow-ssh"
  network = google_compute_network.main.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["ssh"]
}

###############################
# SSH Key
###############################

resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "private_key" {
  content         = tls_private_key.ssh_key.private_key_pem
  filename        = "${path.module}/my-keypair.pem"
  file_permission = "0400"
}

###############################
# VM Instance
###############################

resource "google_compute_instance" "vm" {
  name         = "simple-vm"
  machine_type = var.machine_type
  zone         = var.gcp_zone

  boot_disk {
    initialize_params {
      image = "${var.image_project}/${var.image_family}"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.main.id
    access_config {} # public IP
  }

  metadata = {
    ssh-keys = "debian:${tls_private_key.ssh_key.public_key_openssh}"
  }

  tags = ["ssh"]
}

###############################
# Outputs
###############################

output "public_ip" {
  value = google_compute_instance.vm.network_interface[0].access_config[0].nat_ip
}

output "ssh_command" {
  value = "ssh -i my-keypair.pem debian@${google_compute_instance.vm.network_interface[0].access_config[0].nat_ip}"
}
