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



provider "docker" {
  host = "tcp://localhost:2375"
}

provider "grafana" {
  url  = "http://localhost:3000/"
  auth = "admin:admin" // replace with your Grafana credentials
}


module "grafana" {
  source = "./modules/images"
}