# -------------------------------------------------------
# Confluent Cloud Organization
# -------------------------------------------------------
data "confluent_organization" "cc_org" {
  # This data source fetches the organization details
  # Ensure you have the correct permissions to access the organization
}

# -------------------------------------------------------
# Confluent Cloud Environment
# -------------------------------------------------------
resource "confluent_environment" "cc_demo_env" {
  display_name = "${var.cc_env_name}-${random_id.id.hex}"
  stream_governance {
    package = var.stream_governance
  }
  lifecycle {
    prevent_destroy = false
  }
}
output "cc_demo_env" {
  description = "CC Environment"
  value       = resource.confluent_environment.cc_demo_env.id
}

# --------------------------------------------------------
# Apache Kafka Cluster
# --------------------------------------------------------
resource "confluent_kafka_cluster" "cc_kafka_cluster" {
  display_name = var.cc_cluster_name
  availability = var.cc_availability
  cloud        = var.cc_cloud_provider
  region       = var.cc_cloud_region
  basic {}
  environment {
    id = confluent_environment.cc_demo_env.id
  }
  lifecycle {
    prevent_destroy = false
  }
}
output "cc_kafka_cluster_id" {
  description = "CC Kafka Cluster ID"
  value       = resource.confluent_kafka_cluster.cc_kafka_cluster.id
}
output "cc_kafka_cluster_bootstrap" {
  description = "CC Kafka Cluster Bootstrap Endpoint"
  value       = resource.confluent_kafka_cluster.cc_kafka_cluster.bootstrap_endpoint
}

# --------------------------------------------------------
# Loads the Schema Registry cluster in the target environment
# --------------------------------------------------------
data "confluent_schema_registry_cluster" "cc_sr_cluster" {
  environment {
    id = resource.confluent_environment.cc_demo_env.id
  }
  depends_on = [ 
    resource.confluent_kafka_cluster.cc_kafka_cluster
  ]
}
output "cc_sr_cluster_endpoint" {
  value = data.confluent_schema_registry_cluster.cc_sr_cluster.rest_endpoint
}

# --------------------------------------------------------
# Service Accounts (app_manager, sr, clients)
# --------------------------------------------------------
resource "confluent_service_account" "app_manager" {
  display_name = "app-manager-${random_id.id.hex}"
  description  = "Application Manager Service Account for Confluent Cloud"
  lifecycle {
    prevent_destroy = false
  }
}
resource "confluent_service_account" "sr" {
  display_name = "sr-${random_id.id.hex}"
  description  = "Schema Registry Service Account for Confluent Cloud"
  lifecycle {
    prevent_destroy = false
  }
}
resource "confluent_service_account" "clients" {
  display_name = "client-${random_id.id.hex}"
  description  = "Kafka Clients Service Account for Confluent Cloud"
  lifecycle {
    prevent_destroy = false
  }
}

# --------------------------------------------------------
# Role Bindings (app_manager, sr, clients)
# --------------------------------------------------------
resource "confluent_role_binding" "app_manager_environment_admin" {
  principal   = "User:${confluent_service_account.app_manager.id}"
  role_name   = "EnvironmentAdmin"
  crn_pattern = confluent_environment.cc_demo_env.resource_name
  lifecycle {
    prevent_destroy = false
  }
}
resource "confluent_role_binding" "sr_environment_admin" {
  principal   = "User:${confluent_service_account.sr.id}"
  role_name   = "EnvironmentAdmin"
  crn_pattern = confluent_environment.cc_demo_env.resource_name
  lifecycle {
    prevent_destroy = false
  }
}
resource "confluent_role_binding" "clients_cluster_admin" {
  principal   = "User:${confluent_service_account.clients.id}"
  role_name   = "CloudClusterAdmin"
  crn_pattern = confluent_kafka_cluster.cc_kafka_cluster.rbac_crn
  lifecycle {
    prevent_destroy = false
  }
}

# --------------------------------------------------------
# Credentials / API Keys
# --------------------------------------------------------
# app_manager
resource "confluent_api_key" "app_manager_kafka_cluster_key" {
  display_name = "app-manager-${var.cc_cluster_name}-key-${random_id.id.hex}"
  description  = "Application Manager API Key for Confluent Cloud"
  owner {
    id          = confluent_service_account.app_manager.id
    api_version = confluent_service_account.app_manager.api_version
    kind        = confluent_service_account.app_manager.kind
  }
  managed_resource {
    id          = confluent_kafka_cluster.cc_kafka_cluster.id
    api_version = confluent_kafka_cluster.cc_kafka_cluster.api_version
    kind        = confluent_kafka_cluster.cc_kafka_cluster.kind
    environment {
      id = confluent_environment.cc_demo_env.id
    }
  }
  depends_on = [
    confluent_role_binding.app_manager_environment_admin
  ]
  lifecycle {
    prevent_destroy = false
  }
}
# Schema Registry
resource "confluent_api_key" "sr_cluster_key" {
  display_name = "sr-${var.cc_cluster_name}-key-${random_id.id.hex}"
  description  = "Schema Registry API Key for Confluent Cloud"
  owner {
    id          = confluent_service_account.sr.id
    api_version = confluent_service_account.sr.api_version
    kind        = confluent_service_account.sr.kind
  }
  managed_resource {
    id          = data.confluent_schema_registry_cluster.cc_sr_cluster.id
    api_version = data.confluent_schema_registry_cluster.cc_sr_cluster.api_version
    kind        = data.confluent_schema_registry_cluster.cc_sr_cluster.kind
    environment {
      id = confluent_environment.cc_demo_env.id
    }
  }
  depends_on = [
    confluent_role_binding.sr_environment_admin,
    data.confluent_schema_registry_cluster.cc_sr_cluster
  ]
  lifecycle {
    prevent_destroy = false
  }
}
output "sr_cluster_key" {
  description = "Schema Registry API Key"
  value       = confluent_api_key.sr_cluster_key.id
} 
output "sr_cluster_secret" {
  description = "Schema Registry API Key Secret"
  value       = confluent_api_key.sr_cluster_key.secret
  sensitive   = true
} 
# Kafka clients
resource "confluent_api_key" "clients_kafka_cluster_key" {
  display_name = "clients-${var.cc_cluster_name}-key-${random_id.id.hex}"
  description  = "Kafka Clients API Key for Confluent Cloud"
  owner {
    id          = confluent_service_account.clients.id
    api_version = confluent_service_account.clients.api_version
    kind        = confluent_service_account.clients.kind
  }
  managed_resource {
    id          = confluent_kafka_cluster.cc_kafka_cluster.id
    api_version = confluent_kafka_cluster.cc_kafka_cluster.api_version
    kind        = confluent_kafka_cluster.cc_kafka_cluster.kind
    environment {
      id = confluent_environment.cc_demo_env.id
    }
  }
  depends_on = [
    confluent_role_binding.clients_cluster_admin
  ]
  lifecycle {
    prevent_destroy = false
  }
}
output "clients_kafka_cluster_key" {
  description = "Kafka Clients API Key"
  value       = confluent_api_key.clients_kafka_cluster_key.id
}
output "clients_kafka_cluster_secret" {
  description = "Kafka Clients API Key Secret"
  value       = confluent_api_key.clients_kafka_cluster_key.secret
  sensitive   = true
}
# Flink Compute Pool
resource "confluent_api_key" "flink_api_key" {
  display_name = "flink-${var.cc_cluster_name}-key-${random_id.id.hex}"
  description  = "Flink API Key for Confluent Cloud"
  owner {
    id          = confluent_service_account.app_manager.id
    api_version = confluent_service_account.app_manager.api_version
    kind        = confluent_service_account.app_manager.kind
  }
  managed_resource {
    id          = data.confluent_flink_region.flink_region.id
    api_version = data.confluent_flink_region.flink_region.api_version
    kind        = data.confluent_flink_region.flink_region.kind
    environment {
      id = confluent_environment.cc_demo_env.id
    }
  }
  depends_on = [
    confluent_role_binding.app_manager_environment_admin
  ]
  lifecycle {
    prevent_destroy = false
  }
}

# --------------------------------------------------------
# Kafka topics/schema
# --------------------------------------------------------
# card_transactions 
resource "confluent_kafka_topic" "card_transactions" {
  kafka_cluster {
    id = confluent_kafka_cluster.cc_kafka_cluster.id
  }
  topic_name         = "card-transactions"
  rest_endpoint      = confluent_kafka_cluster.cc_kafka_cluster.rest_endpoint
  credentials {
    key    = confluent_api_key.app_manager_kafka_cluster_key.id
    secret = confluent_api_key.app_manager_kafka_cluster_key.secret
  }
  partitions_count = 1
  config = {
    "cleanup.policy" = "delete"
    "min.insync.replicas" = "2"
    "retention.ms" = "604800000" # 7 days
  }
  lifecycle {
    prevent_destroy = false
  }
}
resource "confluent_schema" "avro-card_transactions" {
  schema_registry_cluster {
    id = data.confluent_schema_registry_cluster.cc_sr_cluster.id
  }
  rest_endpoint = data.confluent_schema_registry_cluster.cc_sr_cluster.rest_endpoint
  subject_name = "card-transactions-value"
  format = "AVRO"
  schema = file("./schemas/card_transactions.avro")
  credentials {
    key    = confluent_api_key.sr_cluster_key.id
    secret = confluent_api_key.sr_cluster_key.secret
  }
  lifecycle {
    prevent_destroy = false
  }
}
# users_config
resource "confluent_kafka_topic" "users_config" {
  kafka_cluster {
    id = confluent_kafka_cluster.cc_kafka_cluster.id
  }
  topic_name         = "users-config"
  rest_endpoint      = confluent_kafka_cluster.cc_kafka_cluster.rest_endpoint
  credentials {
    key    = confluent_api_key.app_manager_kafka_cluster_key.id
    secret = confluent_api_key.app_manager_kafka_cluster_key.secret
  }
  partitions_count = 1
  config = {
    "cleanup.policy" = "compact"
    "min.insync.replicas" = "2"
    "retention.ms" = "-1" # Infinite retention
  }
  lifecycle {
    prevent_destroy = false
  }
}
resource "confluent_schema" "avro-users_config" {
  schema_registry_cluster {
    id = data.confluent_schema_registry_cluster.cc_sr_cluster.id
  }
  rest_endpoint = data.confluent_schema_registry_cluster.cc_sr_cluster.rest_endpoint
  subject_name = "users-config-value"
  format = "AVRO"
  schema = file("./schemas/users_config.avro")
  credentials {
    key    = confluent_api_key.sr_cluster_key.id
    secret = confluent_api_key.sr_cluster_key.secret
  }
  lifecycle {
    prevent_destroy = false
  }
}

# --------------------------------------------------------
# Flink Compute Pool
# --------------------------------------------------------
resource "confluent_flink_compute_pool" "flink_compute_pool" {
  display_name     = "standard_compute_pool"
  cloud            = var.cc_cloud_provider
  region           = var.cc_cloud_region
  max_cfu          = var.flink_cfu
  environment {
    id = confluent_environment.cc_demo_env.id
  }
}
data "confluent_flink_region" "flink_region" {
  cloud = var.cc_cloud_provider
  region = var.cc_cloud_region
}

# --------------------------------------------------------
# Flink Statements
# --------------------------------------------------------
resource "confluent_flink_statement" "alter_card_transactions_enriched" {
  organization {
    id = data.confluent_organization.cc_org.id
  }
  environment {
    id = confluent_environment.cc_demo_env.id
  }
  compute_pool {
    id = confluent_flink_compute_pool.flink_compute_pool.id
  }
  principal {
    id = confluent_service_account.app_manager.id
  }
  statement = file("./sql/alter-table_card-transactions-enriched.sql")
  properties = {
    "sql.current-catalog"  = resource.confluent_environment.cc_demo_env.id
    "sql.current-database" = resource.confluent_kafka_cluster.cc_kafka_cluster.id
  }
  rest_endpoint = data.confluent_flink_region.flink_region.rest_endpoint
  credentials {
    key    = confluent_api_key.flink_api_key.id
    secret = confluent_api_key.flink_api_key.secret
  }
  lifecycle {
    prevent_destroy = false
  }
  depends_on = [
    confluent_flink_compute_pool.flink_compute_pool,
    confluent_kafka_topic.card_transactions
  ]
}

resource "confluent_flink_statement" "create_table_card_transactions_enriched" {
  organization {
    id = data.confluent_organization.cc_org.id
  }
  environment {
    id = confluent_environment.cc_demo_env.id
  }
  compute_pool {
    id = confluent_flink_compute_pool.flink_compute_pool.id
  }
  principal {
    id = confluent_service_account.app_manager.id
  }
  statement = file("./sql/create-table_card-transactions-enriched.sql")
  properties = {
    "sql.current-catalog"  = resource.confluent_environment.cc_demo_env.id
    "sql.current-database" = resource.confluent_kafka_cluster.cc_kafka_cluster.id
  }
  rest_endpoint = data.confluent_flink_region.flink_region.rest_endpoint
  credentials {
    key    = confluent_api_key.flink_api_key.id
    secret = confluent_api_key.flink_api_key.secret
  }
  lifecycle {
    prevent_destroy = false
  }
  depends_on = [
    confluent_flink_compute_pool.flink_compute_pool,
    confluent_flink_statement.alter_card_transactions_enriched
  ]
}

resource "confluent_flink_statement" "insert_card_transactions_enriched" {
  organization {
    id = data.confluent_organization.cc_org.id
  }
  environment {
    id = confluent_environment.cc_demo_env.id
  }
  compute_pool {
    id = confluent_flink_compute_pool.flink_compute_pool.id
  }
  principal {
    id = confluent_service_account.app_manager.id
  }
  statement = file("./sql/insert_card-transactions-enriched.sql")
  properties = {
    "sql.current-catalog"  = resource.confluent_environment.cc_demo_env.id
    "sql.current-database" = resource.confluent_kafka_cluster.cc_kafka_cluster.id
  }
  rest_endpoint = data.confluent_flink_region.flink_region.rest_endpoint
  credentials {
    key    = confluent_api_key.flink_api_key.id
    secret = confluent_api_key.flink_api_key.secret
  }
  lifecycle {
    prevent_destroy = false
  }
  depends_on = [
    confluent_flink_compute_pool.flink_compute_pool,
    confluent_flink_statement.create_table_card_transactions_enriched
  ]
}