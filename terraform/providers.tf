terraform {
  required_providers {
    confluent = {
      source  = "confluentinc/confluent"
      version = "2.30.0"
    }
  }
}

provider "confluent" {
  # Environment variables to be set on ./env (see README.md)
  #CONFLUENT_CLOUD_API_KEY    = "XXXXX"
  #CONFLUENT_CLOUD_API_SECRET = "XXXXX"
}
