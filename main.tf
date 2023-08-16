terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 2.14.0" // specify the version you want
    }
    grafana = {
      source = "grafana/grafana"
      version = "~> 1.40.1" // specify the version you want here
    }
  }
}


variable "choco_installed" {
  description = "Is Chocolatey installed?"
  type        = bool
  default     = false
}

variable "terraform_installed" {
  description = "Is Terraform installed via Chocolatey?"
  type        = bool
  default     = false
}

variable "docker_desktop_installed" {
  description = "Is Docker Desktop installed via Chocolatey?"
  type        = bool
  default     = false
}



##requirements check

resource "null_resource" "check_requirements" {

  provisioner "local-exec" {
    command = <<EOF
      powershell -command "if (Get-Command choco -ErrorAction SilentlyContinue) { Set-Variable -Name TF_VAR_choco_installed -Value true -Scope Global }"
      powershell -command "if (Get-Command terraform -ErrorAction SilentlyContinue) { Set-Variable -Name TF_VAR_terraform_installed -Value true -Scope Global }"
      powershell -command "if (Get-Command docker -ErrorAction SilentlyContinue) { Set-Variable -Name TF_VAR_docker_desktop_installed -Value true -Scope Global }"
    EOF
  }

}

#End requirements check

##requirements install

resource "null_resource" "install_choco" {

  provisioner "local-exec" {
    command = <<EOF
      powershell -command "if (-not (Get-Variable -Name TF_VAR_choco_installed -ErrorAction SilentlyContinue)) { .\choco-install.ps1 }"
    EOF
  }

}

resource "null_resource" "install_terraform" {

  provisioner "local-exec" {
    command = <<EOF
      powershell -command "if (-not (Get-Variable -Name TF_VAR_terraform_installed -ErrorAction SilentlyContinue)) { .\terraform-install.ps1 }"
    EOF
  }

}

resource "null_resource" "install_docker_desktop" {

  provisioner "local-exec" {
    command = <<EOF
      powershell -command "if (-not (Get-Variable -Name TF_VAR_docker_desktop_installed -ErrorAction SilentlyContinue)) { .\docker_desktop-install.ps1 }"
    EOF
  }

}

resource "null_resource" "configure_docker_desktop" {
  depends_on = [null_resource.install_docker_desktop]

  provisioner "local-exec" {
    command = <<EOF
      powershell -command "if ((Get-Variable -Name TF_VAR_docker_desktop_installed -ErrorAction SilentlyContinue) -or (Get-Command docker -ErrorAction SilentlyContinue)) { .\docker_desktop-configure.ps1 }"
    EOF
  }
}


#End requirements install
provider "docker" {
  host = var.docker_desktop_installed ? "tcp://localhost:2375" : null
}

variable "host_path" {
  description = "The path on the host where the volume data should be stored."
  type        = string
  default     = "./"
}

data "external" "local_ip" {
  program = ["powershell", "-Command", "@{ip = (Test-Connection -ComputerName (hostname) -Count 1).IPv4Address.IPAddressToString} | ConvertTo-Json"]
}


variable "physical_ip" {
  description = "The physical IP of the host machine"
  type        = string
  default     = ""
}

locals {
  absolute_host_path = replace(abspath(var.host_path),":","")
}

resource "docker_image" "prometheus" {
  name = "prom/prometheus:latest"
}

resource "docker_volume" "prometheus_data" {
  name = "prometheus_data"
}

resource "null_resource" "create_dir" {
  provisioner "local-exec" {
    command = <<EOF
      powershell -Command "if (!(Test-Path '${replace(abspath(var.host_path),"/","\\")}\prometheus')) {New-Item -ItemType Directory -Force -Path '${replace(abspath(var.host_path),"/","\\")}\prometheus'}"
              EOF
  }
  triggers = {
    host_path = var.host_path
  }
}


resource "local_file" "prometheus_config" {
  depends_on = [null_resource.create_dir]

  filename = "${var.host_path}/prometheus/prometheus.yml"
  content  = <<EOF
                global:
                  scrape_interval:     15s
                  evaluation_interval: 15s

                scrape_configs:
                - job_name: 'docker'
                  scrape_interval: 5s
                  static_configs:
                  - targets: ['${coalesce(var.physical_ip, data.external.local_ip.result["ip"])}:9323']

                - job_name: 'cadvisor'
                  scrape_interval: 5s
                  static_configs:
                  - targets: ['${coalesce(var.physical_ip, data.external.local_ip.result["ip"])}:8081']
                - job_name: 'node-exporter'
                  scrape_interval: 5s
                  static_configs:
                  - targets: ['${coalesce(var.physical_ip, data.external.local_ip.result["ip"])}:9100']
                EOF
}


resource "docker_container" "prometheus" {
  name  = "prometheus"
  image = docker_image.prometheus.name

  volumes {
    host_path = "/${local.absolute_host_path}/prometheus"
    container_path = "/etc/prometheus"
    read_only      = false
  }

  volumes {
    volume_name = docker_volume.prometheus_data.name
    container_path = "/prometheus"
  }

  command = [
    "--config.file=/etc/prometheus/prometheus.yml",
    "--storage.tsdb.path=/prometheus",
    "--web.console.libraries=/usr/share/prometheus/console_libraries",
    "--web.console.templates=/usr/share/prometheus/consoles"
  ]

  ports {
    internal = 9090
    external = 9090
  }

  restart = "always"

  depends_on = [local_file.prometheus_config]
}

resource "docker_image" "grafana" {
  name = "grafana/grafana:latest"
}

resource "docker_volume" "grafana_data" {
  name = "grafana_data"
}

resource "local_file" "grafana_provisioning_dashboard" {
  content = <<-EOF
    apiVersion: 1

    providers:
    - name: 'Prometheus'
      orgId: 1
      folder: ''
      type: file
      disableDeletion: false
      editable: true
      options:
        path: /etc/grafana/provisioning/dashboards
  EOF
  filename = "${abspath(var.host_path)}/grafana/provisioning/dashboards/dashboard.yml"
}

output "absolute_host_path" {
  description = "The absolute host path"
  value       = abspath(var.host_path)
}


resource "docker_container" "grafana" {
  name  = "grafana"
  image = docker_image.grafana.name

  depends_on = [docker_container.prometheus]

  user = "472"

  volumes {
    host_path = "/${local.absolute_host_path}/grafana_data"
    container_path = "/var/lib/grafana"
    read_only      = false
  }

  volumes {
    host_path = "/${local.absolute_host_path}/grafana/provisioning"
    container_path = "/etc/grafana/provisioning"
    read_only      = false
  }

  ports {
    internal = 3000
    external = 3000
  }

  restart = "always"
}

resource "docker_image" "cadvisor" {
  name = "google/cadvisor:latest"
}

resource "docker_container" "cadvisor" {
  name  = "cadvisor"
  image = docker_image.cadvisor.name

  volumes {
    host_path      = "/var/run"
    container_path = "/var/run"
    read_only      = false
  }

  volumes {
    host_path      = "/sys"
    container_path = "/sys"
    read_only      = true
  }

  volumes {
    host_path      = "/var/lib/docker/"
    container_path = "/var/lib/docker/"
    read_only      = true
  }

  ports {
    internal = 8080
    external = 8081
  }

  restart = "always"
}

resource "docker_image" "node_exporter" {
  name = "prom/node-exporter:latest"
}

resource "docker_container" "node_exporter" {
  image = "${docker_image.node_exporter.latest}"
  name  = "node-exporter"

  volumes {
    container_path  = "/host/proc"
    host_path       = "/proc"
    read_only       = true
  }

  volumes {
    container_path  = "/host/sys"
    host_path       = "/sys"
    read_only       = true
  }

  ports {
    internal = 9100
    external = 9100
  }

  restart = "always"

  command = [
    "--path.procfs=/host/proc",
    "--path.sysfs=/host/sys",
    "--collector.filesystem.ignored-mount-points=^/(sys|proc|dev|host|etc|rootfs/var/lib/docker/containers|rootfs/var/lib/docker/overlay2|rootfs/run/docker/netns|rootfs/var/lib/docker/aufs)($$|/)"
  ]
}


resource "null_resource" "grafana_wait" {
  triggers = {
    grafana_id = docker_container.grafana.id
  }

  provisioner "local-exec" {
    command = "powershell -Command \"do{Start-Sleep -s 5; \\= try { Invoke-WebRequest http://localhost:3000 -UseBasicParsing -DisableKeepAlive -Method Head } catch {\\}} until (\\.StatusCode -eq 200)\""
  }
  
}

provider "grafana" {
  url  = "http://localhost:3000/"
  auth = "admin:admin" // replace with your Grafana credentials
}

resource "grafana_data_source" "prometheus" {
  type          = "prometheus"
  name          = "Prometheus"
  url           = "http://${coalesce(var.physical_ip, data.external.local_ip.result["ip"])}:9090"
  access_mode   = "proxy"
  is_default = true

  provisioner "local-exec" {
    command = "powershell -Command \"do{Start-Sleep -s 5; \\$response= try { Invoke-WebRequest http://localhost:3000 -UseBasicParsing -DisableKeepAlive -Method Head } catch {\\$_}} until (\\$response.StatusCode -eq 200)\""
  }

  depends_on = [null_resource.grafana_wait]
}




