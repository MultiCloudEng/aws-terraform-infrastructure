output "web_public_ip" {
  value = module.web.public_ip
}

output "api_public_ip" {
  value = module.api.public_ip
}
