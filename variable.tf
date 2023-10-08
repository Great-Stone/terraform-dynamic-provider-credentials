variable "tfc_hostname" {
  type    = string
  default = "app.terraform.io"
}

variable "tfc_organization_name" {
  type    = string
  default = "dynamic-provider"
}

variable "tfc_project_name" {
  type    = string
  default = "Default Project"
}

variable "tfc_aws_audience" {
  type    = string
  default = "aws.workload.identity"
}

variable "tfc_azure_audience" {
  type    = string
  default = "api://AzureADTokenExchange"
}

variable "tfc_gcp_audience" {
  type    = string
  default = ""
}

variable "vault_namespace" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "gcp_region" {
  type = string
}

variable "gcp_project" {
  type = string
}

variable "hcp_vault_cluster_project_id" {
  type = string
}

variable "hcp_vault_cluster_cluster_id" {
  type = string
}