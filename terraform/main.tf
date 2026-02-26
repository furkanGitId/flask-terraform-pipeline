terraform {
  required_version = ">= 1.5"

  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

# Connect Terraform to Docker on your machine
provider "docker" {
  host = "unix:///var/run/docker.sock"
}

# ── Variables ─────────────────────────────────────────────────────────────────
variable "docker_image" {
  description = "Image to deploy — passed in from Jenkinsfile"
  type        = string
  default     = "furkandevops/flask-terraform-pipeline:latest"
}

variable "app_port" {
  description = "Flask app port"
  type        = number
  default     = 5000
}

variable "container_name" {
  description = "Name of the running container"
  type        = string
  default     = "flask-terraform-app"
}

# ── Pull image from Docker Hub ────────────────────────────────────────────────
resource "docker_image" "app" {
  name         = var.docker_image
  keep_locally = false
}

# ── Remove old container and run new one ─────────────────────────────────────
resource "docker_container" "app" {
  name  = var.container_name
  image = docker_image.app.image_id

  # Always restart if it crashes
  restart = "always"

  # port 5000 inside container → port 5000 on your machine
  ports {
    internal = var.app_port
    external = var.app_port
  }

  env = [
    "FLASK_ENV=production"
  ]

  # Force replace container when image changes (new build = new container)
  must_run = true

  healthcheck {
    test         = ["CMD", "curl", "-f", "http://localhost:5000/health"]
    interval     = "30s"
    timeout      = "10s"
    retries      = 3
    start_period = "15s"
  }
}

# ── Print results after deploy ────────────────────────────────────────────────
output "app_url" {
  value = "http://localhost:${var.app_port}"
}

output "container_name" {
  value = docker_container.app.name
}

output "image_deployed" {
  value = var.docker_image
}