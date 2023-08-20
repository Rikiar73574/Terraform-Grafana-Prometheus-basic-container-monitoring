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

//to be done: add check for all three programs

resource "null_resource" "install_choco" {
  count = var.choco_installed ? 0 : 1

  provisioner "local-exec" {
    command = <<EOF
      powershell Start-Process -Verb RunAs powershell.exe -ArgumentList "-Command Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))"
      EOF
  }
  
}

resource "null_resource" "install_terraform" {
  count = var.terraform_installed ? 0 : 1
  depends_on = [null_resource.install_choco]
  provisioner "local-exec" {
    command = <<EOF
      powershell.exe -ExecutionPolicy Bypass -File ${abspath(path.module)}\Terraform_Helpers\terraform-install.ps1 
    EOF
  }
}

resource "null_resource" "install_docker_desktop" {
  count = var.docker_desktop_installed ? 0 : 1
  depends_on = [null_resource.install_choco]
  provisioner "local-exec" {
    command = <<EOF
      powershell.exe -ExecutionPolicy Bypass -File ${abspath(path.module)}\Terraform_Helpers\docker-desktop-install.ps1 
    EOF
  }
}



resource "null_resource" "configure_docker_desktop" {
  depends_on = [null_resource.install_docker_desktop]
  count = var.docker_desktop_installed ? 0 : 1
 provisioner "local-exec" {
   command = <<EOF
     powershell.exe -ExecutionPolicy Bypass -File ${abspath(path.module)}\Terraform_Helpers\docker-configure.ps1 
   EOF
 }
 
}



output "all_installed" {
  description = "Are all softwares installed?"
  value       = var.choco_installed && var.terraform_installed && var.docker_desktop_installed
}
