variable "nsx_ip" {
  description = "NSX Manager FQDN or IP"
}

variable "nsx_user" {
  description = "NSX Manager user"
}

variable "nsx_password" {
  description = "NSX Manager password"
}

# Segment Names
variable "left_uplink_v18" {
    default = "left_uplink_v18"
}
variable "right_uplink_v19" {
    default = "right_uplink_v19"
}