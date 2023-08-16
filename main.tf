module "requirements" {
  source = "./modules/requirements"
  // Add any required variables here.
}

module "grafana" {
  source = "./modules/images"
  // Add any required variables here.

  depends_on = [module.requirements]
}
