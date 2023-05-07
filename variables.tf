variable "region" {
  type    = string
  default = "northeurope"
}

variable "resource_group" {
  type    = string
  default = "aks-test"
}

variable "cluster_name" {
  type    = string
  default = "aks-test"
}

variable "control_nodes" {
  type    = string
  default = "akscontrol"
}

variable "worker_nodes" {
  type    = string
  default = "aksworker"
}

variable "dns_prefix" {
  type    = string
  default = "aks-test"
}

variable "k8s_version" {
  type = string
}

variable "min_node_count" {
  type    = number
  default = 3
}

variable "max_node_count" {
  type    = number
  default = 6
}

variable "machine_type" {
  type    = string
  default = "Standard_D2_v2"
}
