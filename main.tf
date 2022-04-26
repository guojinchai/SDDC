terraform {
  required_providers {
    nsxt = {
      source = "vmware/nsxt"
    }
  }
}

provider "nsxt" {
  host                 = var.nsx_ip
  username             = var.nsx_user
  password             = var.nsx_password
  allow_unverified_ssl = true
  max_retries          = 2
}

data "nsxt_policy_transport_zone" "overlay_tz" {
    display_name = "overlay-tz"
}

data "nsxt_policy_transport_zone" "vlan_tz" {
    display_name = "vlan-tz"
}

data "nsxt_policy_edge_cluster" "edge_cluster" {
    display_name = "edge-cluster-1"
}

data "nsxt_policy_tier0_gateway" "tier0_gw" {
  display_name = "t0-gw"
}

#data "nsxt_policy_tier1_gateway" "tier1_gw" {
  #display_name = "t1-gw"
#}

data "nsxt_policy_edge_node" "edge_node_01" {
  edge_cluster_path = data.nsxt_policy_edge_cluster.edge_cluster.path
  member_index      = 0
}

data "nsxt_policy_edge_node" "edge_node_02" {
  edge_cluster_path = data.nsxt_policy_edge_cluster.edge_cluster.path
  member_index      = 1
}

resource "nsxt_policy_vlan_segment" "left_uplink_v18" {
    display_name = var.left_uplink_v18
    description = "Segment created by Terraform"
    transport_zone_path = data.nsxt_policy_transport_zone.vlan_tz.path
    vlan_ids            = [18]
}

resource "nsxt_policy_vlan_segment" "right_uplink_v19" {
    display_name = var.right_uplink_v19
    description = "Segment created by Terraform"
    transport_zone_path = data.nsxt_policy_transport_zone.vlan_tz.path
    vlan_ids            = [19]
}

resource "nsxt_policy_tier0_gateway" "tier0_gw" {
  description              = "Tier-0 provisioned by Terraform"
  display_name             = "t0-gw"
  default_rule_logging     = false
  enable_firewall          = true
  ha_mode                  = "ACTIVE_ACTIVE"
  edge_cluster_path        = data.nsxt_policy_edge_cluster.edge_cluster.path
}

resource "nsxt_policy_tier0_gateway_interface" "left_uplink_v18_edge01" {
  display_name           = "left-uplink-v18-edge01"
  type                   = "EXTERNAL"
  gateway_path           = data.nsxt_policy_tier0_gateway.tier0_gw.path
  edge_node_path         = data.nsxt_policy_edge_node.edge_node_01.path
  segment_path           = nsxt_policy_vlan_segment.left_uplink_v18.path
  subnets                = ["192.168.18.31/24"]
  mtu                    = 1700
}

resource "nsxt_policy_tier0_gateway_interface" "left_uplink_v18_edge02" {
  display_name           = "left-uplink-v18-edge02"
  type                   = "EXTERNAL"
  gateway_path           = data.nsxt_policy_tier0_gateway.tier0_gw.path
  edge_node_path         = data.nsxt_policy_edge_node.edge_node_02.path
  segment_path           = nsxt_policy_vlan_segment.left_uplink_v18.path
  subnets                = ["192.168.18.32/24"]
  mtu                    = 1700
}

resource "nsxt_policy_tier0_gateway_interface" "right_uplink_v19_edge01" {
  display_name           = "right-uplink-v19-edge01"
  type                   = "EXTERNAL"
  gateway_path           = data.nsxt_policy_tier0_gateway.tier0_gw.path
  edge_node_path         = data.nsxt_policy_edge_node.edge_node_01.path
  segment_path           = nsxt_policy_vlan_segment.right_uplink_v19.path
  subnets                = ["192.168.19.31/24"]
  mtu                    = 1700
}

resource "nsxt_policy_tier0_gateway_interface" "right_uplink_v19_edge02" {
  display_name           = "right-uplink-v19-edge02"
  type                   = "EXTERNAL"
  gateway_path           = data.nsxt_policy_tier0_gateway.tier0_gw.path
  edge_node_path         = data.nsxt_policy_edge_node.edge_node_02.path
  segment_path           = nsxt_policy_vlan_segment.right_uplink_v19.path
  subnets                = ["192.168.19.32/24"]
  mtu                    = 1700
}

locals {
  # Concatinate Uplink Source IP's for ToR-A Peering
  uplink_v18_source_addresses = concat(
    nsxt_policy_tier0_gateway_interface.left_uplink_v18_edge01.ip_addresses,
    nsxt_policy_tier0_gateway_interface.left_uplink_v18_edge02.ip_addresses
  )
  # Concatinate Uplink Source IP's for ToR-B Peering
  uplink_v19_source_addresses = concat(
    nsxt_policy_tier0_gateway_interface.right_uplink_v19_edge01.ip_addresses,
    nsxt_policy_tier0_gateway_interface.right_uplink_v19_edge02.ip_addresses
  )
}

resource "nsxt_policy_bgp_config" "t0_bgp_config" {
  gateway_path = nsxt_policy_tier0_gateway.tier0_gw.path
  enabled                = true
  inter_sr_ibgp          = true
  ecmp                   = true
  multipath_relax        = true
  local_as_num           = 65000
}

resource "nsxt_policy_bgp_neighbor" "t0_bgp_neighbor" {
  display_name          = "t0_bgp_neighbor"
  bgp_path              = nsxt_policy_tier0_gateway.tier0_gw.bgp_config.0.path
  allow_as_in           = false
  graceful_restart_mode = "HELPER_ONLY"
  hold_down_time        = 300
  keep_alive_time       = 100
  neighbor_address      = "192.168.18.30"
  remote_as_num         = "65100"
  source_addresses = local.uplink_v18_source_addresses

  bfd_config {
    enabled  = true
  }
}

resource "nsxt_policy_bgp_neighbor" "t0_bgp_neighbor_b" {
  display_name          = "t0_bgp_neighbor_b"
  bgp_path              = nsxt_policy_tier0_gateway.tier0_gw.bgp_config.0.path
  allow_as_in           = false
  graceful_restart_mode = "HELPER_ONLY"
  hold_down_time        = 300
  keep_alive_time       = 100
  neighbor_address      = "192.168.19.30"
  remote_as_num         = "65100"
  source_addresses = local.uplink_v19_source_addresses

  bfd_config {
    enabled  = true
  }
}

resource "nsxt_policy_tier1_gateway" "tier1_gw" {
  description               = "Tier-1 provisioned by Terraform"
  display_name              = "t1-gw"
  nsx_id                    = "predefined_id"
  edge_cluster_path         = data.nsxt_policy_edge_cluster.edge_cluster.path
  failover_mode             = "NON_PREEMPTIVE"
  default_rule_logging      = "false"
  enable_firewall           = "true"
  enable_standby_relocation = "false"
  tier0_path                = data.nsxt_policy_tier0_gateway.tier0_gw.path
  route_advertisement_types = ["TIER1_STATIC_ROUTES", "TIER1_CONNECTED"]
  pool_allocation           = "ROUTING"
}

resource "nsxt_policy_segment" "segment1" {
  display_name        = "segment1"
  description         = "Terraform provisioned Segment"
  connectivity_path   = nsxt_policy_tier1_gateway.tier1_gw.path
  transport_zone_path = data.nsxt_policy_transport_zone.overlay_tz.path
  
  subnet {
    cidr        = "10.0.10.1/24"
  }
}

resource "nsxt_policy_gateway_redistribution_config" "Redis-BGP" {
  gateway_path = data.nsxt_policy_tier0_gateway.tier0_gw.path
  bgp_enabled  = true

  rule {
    name = "Redis-BGP"
    types = [
              "TIER0_CONNECTED",
              "TIER0_STATIC",
              "TIER1_CONNECTED",
              "TIER1_STATIC",
            ]
  }
}