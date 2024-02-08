terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.0.0"
    }
  }
}


provider "azurerm" {
  features {}
}

resource "random_integer" "ri" {
  min = 10000
  max = 99999
}

# Create Resource group
resource "azurerm_resource_group" "azrg" {
  name     = "${var.resource_group_name}${random_integer.ri.result}"
  location = var.resource_group_location
}

resource "azurerm_service_plan" "azsp" {
  name                = "${var.app_service_plan_name}${random_integer.ri.result}"
  resource_group_name = azurerm_resource_group.azrg.name
  location            = azurerm_resource_group.azrg.location
  os_type             = "Linux"
  sku_name            = "F1"
}

resource "azurerm_linux_web_app" "azlwa" {
  name                = "${var.app_service_name}${random_integer.ri.result}"
  resource_group_name = azurerm_resource_group.azrg.name
  location            = azurerm_service_plan.azsp.location
  service_plan_id     = azurerm_service_plan.azsp.id

  site_config {
    application_stack {
      dotnet_version = "6.0"
    }
    always_on = false
  }

  connection_string {
    name  = "DefaultConnection"
    type  = "SQLAzure"
    value = "Data Source=tcp:${azurerm_mssql_server.azserver.fully_qualified_domain_name},1433;Initial Catalog=${var.sql_database_name};User ID=${azurerm_mssql_server.azserver.administrator_login};Password=${azurerm_mssql_server.azserver.administrator_login_password};Trusted_Connection=False; MultipleActiveResultSets=True;"
  }
}

# Create an Azure SQL Server
resource "azurerm_mssql_server" "azserver" {
  name                         = "${var.sql_server_name}${random_integer.ri.result}"
  resource_group_name          = azurerm_resource_group.azrg.name
  location                     = azurerm_resource_group.azrg.location
  version                      = "12.0"
  administrator_login          = var.sql_server_login_username
  administrator_login_password = var.sql_server_login_password
}

# Create an Azure SQL Database
resource "azurerm_mssql_database" "azdb" {
  name           = "${var.sql_database_name}${random_integer.ri.result}"
  server_id      = azurerm_mssql_server.azserver.id
  collation      = "SQL_Latin1_General_CP1_CI_AS"
  license_type   = "LicenseIncluded"
  max_size_gb    = 2
  sku_name       = "S0"
  zone_redundant = false
}

# Create a firewall rule for the Azure SQL Server
resource "azurerm_mssql_firewall_rule" "azfw" {
  name             = var.firewall_rule_name
  server_id        = azurerm_mssql_server.azserver.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

resource "azurerm_app_service_source_control" "azsc" {
  app_id                 = azurerm_linux_web_app.azlwa.id
  repo_url               = var.github_repo_url
  branch                 = "master"
  use_manual_integration = true
}




