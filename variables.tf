variable "region" {
  default = "eu-central-1"
}
variable "instance_type" {
  default = "t2.micro"
}
variable "allow_ports" {
  description = "List of open ports"
  default     = ["80", "443", "22"]
  type        = list(any)
}
variable "all_tags" {
  description = "Tags for all resources"
  type        = map(string)
  default = {
    Project     = "ResidentE"
    Owner       = "Umbrella"
    Environment = "Dev"
    Year        = "2021"
  }
}
