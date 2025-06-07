locals {
  description = "Resource created using terraform"
}

# --------------------------------------------------------
# This 'random_id_4' will make whatever you create (names, etc)
# unique in your account.
# --------------------------------------------------------
resource "random_id" "id" {
  byte_length = 4
}

# ----------------------------------------
# Confluent Cloud Kafka cluster variables
# ----------------------------------------
variable "cc_cloud_provider" {
  type    = string
  default = "AWS"
}

variable "cc_cloud_region" {
  type    = string
  default = "eu-west-1"
}

variable "cc_env_name" {
  type    = string
  default = "env-demo-card-transactions"
}

variable "cc_cluster_name" {
  type    = string
  default = "cc-demo-main"
}

variable "cc_availability" {
  type    = string
  default = "SINGLE_ZONE"
}

variable "stream_governance" {
  type    = string
  default = "ESSENTIALS"
}

variable "flink_cfu" {
  type    = number
  default = 5
}
