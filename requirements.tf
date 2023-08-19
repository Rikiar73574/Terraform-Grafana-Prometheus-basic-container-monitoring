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

resource "null_resource" "check_requirements" {
  provisioner "local-exec" {
    command = <<EOF
      powershell -Command "& {Start-Process powershell -ArgumentList '-ExecutionPolicy Bypass -File ${path.module}\Terraform_Helpers\choco-check.ps1' -Verb RunAs}"
      powershell -Command "& {Start-Process powershell -ArgumentList '-ExecutionPolicy Bypass -File ${path.module}\Terraform_Helpers\terraform-check.ps1' -Verb RunAs}"
      powershell -Command "& {Start-Process powershell -ArgumentList '-ExecutionPolicy Bypass -File ${path.module}\Terraform_Helpers\docker_desktop-check.ps1' -Verb RunAs}"
    EOF
  }
}

resource "null_resource" "install_choco" {
  count = var.choco_installed ? 0 : 1

  provisioner "local-exec" {
    command = <<EOF
      powershell -Command "& {Start-Process powershell -ArgumentList '-ExecutionPolicy Bypass -File ${path.module}\Terraform_Helpers\choco-install.ps1' -Verb RunAs}"
    EOF
  }
}

resource "null_resource" "install_terraform" {
  count = var.terraform_installed ? 0 : 1

  provisioner "local-exec" {
    command = <<EOF
      powershell -Command "& {Start-Process powershell -ArgumentList '-ExecutionPolicy Bypass -File ${path.module}\Terraform_Helpers\terraform-install.ps1' -Verb RunAs}"
    EOF
  }
}

resource "null_resource" "install_docker_desktop" {
  count = var.docker_desktop_installed ? 0 : 1

  provisioner "local-exec" {
    command = <<EOF
      powershell -Command "& {Start-Process powershell -ArgumentList '-ExecutionPolicy Bypass -File ${path.module}\Terraform_Helpers\docker_desktop-install.ps1' -Verb RunAs}"
    EOF
  }
}



resource "null_resource" "configure_docker_desktop" {
  depends_on = [null_resource.install_docker_desktop]
  count = var.docker_desktop_installed ? 0 : 1
 provisioner "local-exec" {
   command = <<EOF
     powershell -Command "& {Start-Process powershell -ArgumentList '-ExecutionPolicy Bypass -File ${path.module}\\Terraform_Helpers\\docker_desktop-configure.ps1' -Verb RunAs}"
   EOF
 }
 
}



output "all_installed" {
  description = "Are all softwares installed?"
  value       = var.choco_installed && var.terraform_installed && var.docker_desktop_installed
}
