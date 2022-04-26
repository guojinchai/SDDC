variable "nsx_ip" {
  default = "nsxt-mgr.acme.com"
}

variable "nsx_user" {
  default = "admin"
}

variable "nsx_password" {
  default = "txu@mvR7wh8y"
}

# Segment Names
variable "left_uplink_v18" {
    default = "left_uplink_v18"
}
variable "right_uplink_v19" {
    default = "right_uplink_v19"
}