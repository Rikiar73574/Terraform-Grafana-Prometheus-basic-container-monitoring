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
      Start-Process -FilePath 'powershell' -ArgumentList '-Command if (Get-Command choco -ErrorAction SilentlyContinue) { Set-Variable -Name TF_VAR_choco_installed -Value true -Scope Global }' -Verb RunAs
      Start-Process -FilePath 'powershell' -ArgumentList '-Command if (Get-Command terraform -ErrorAction SilentlyContinue) { Set-Variable -Name TF_VAR_terraform_installed -Value true -Scope Global }' -Verb RunAs
      Start-Process -FilePath 'powershell' -ArgumentList '-Command if (Get-Command docker -ErrorAction SilentlyContinue) { Set-Variable -Name TF_VAR_docker_desktop_installed -Value true -Scope Global }' -Verb RunAs
    EOF
  }
}

resource "null_resource" "install_choco" {
  provisioner "local-exec" {
    command = <<EOF
      Start-Process -FilePath 'powershell' -ArgumentList '-Command Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope CurrentUser; if (-not (Get-Variable -Name TF_VAR_choco_installed -ErrorAction SilentlyContinue)) { .\Terraform_Helpers\choco-install.ps1 }; Set-ExecutionPolicy -ExecutionPolicy Restricted -Scope CurrentUser' -Verb RunAs
    EOF
  }
}

resource "null_resource" "install_terraform" {
  provisioner "local-exec" {
    command = <<EOF
      Start-Process -FilePath 'powershell' -ArgumentList '-Command Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope CurrentUser; if (-not (Get-Variable -Name TF_VAR_terraform_installed -ErrorAction SilentlyContinue)) { .\Terraform_Helpers\terraform-install.ps1 }; Set-ExecutionPolicy -ExecutionPolicy Restricted -Scope CurrentUser' -Verb RunAs
    EOF
  }
}

resource "null_resource" "install_docker_desktop" {
  provisioner "local-exec" {
    command = <<EOF
      Start-Process -FilePath 'powershell' -ArgumentList '-Command Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope CurrentUser; if (-not (Get-Variable -Name TF_VAR_docker_desktop_installed -ErrorAction SilentlyContinue)) { .\Terraform_Helpers\docker_desktop-install.ps1 }; Set-ExecutionPolicy -ExecutionPolicy Restricted -Scope CurrentUser' -Verb RunAs
    EOF
  }
}

resource "null_resource" "configure_docker_desktop" {
  depends_on = [null_resource.install_docker_desktop]

  provisioner "local-exec" {
    command = <<EOF
      Start-Process -FilePath 'powershell' -ArgumentList '-Command Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope CurrentUser; if ((Get-Variable -Name TF_VAR_docker_desktop_installed -ErrorAction SilentlyContinue) -or (Get-Command docker -ErrorAction SilentlyContinue)) { .\Terraform_Helpers\docker_desktop-configure.ps1 }; Set-ExecutionPolicy -ExecutionPolicy Restricted -Scope CurrentUser' -Verb RunAs
    EOF
  }
}



output "all_installed" {
  description = "Are all softwares installed?"
  value       = var.choco_installed && var.terraform_installed && var.docker_desktop_installed
}
