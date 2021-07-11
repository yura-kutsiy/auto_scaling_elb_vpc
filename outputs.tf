output "Rregion_description" {
  value = data.aws_region.current.description
}

output "Region_name" {
  value = data.aws_region.current.name
}

output "Availability_zones" {
  value = data.aws_availability_zones.available.names
}

output "Umbrella_url_hier" {
  value = aws_elb.server.dns_name
}
