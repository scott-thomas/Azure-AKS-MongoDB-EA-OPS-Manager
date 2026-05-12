# modules/aks/main.tf

resource "azurerm_resource_group" "aks" {
  name     = var.resource_group_name
  location = var.location

  lifecycle {
    ignore_changes = [
      tags["CreatedOnDate"],
      tags["mongodb_infosec_creator"],
    ]
  }
}

resource "azurerm_virtual_network" "aks" {
  name                = "${var.cluster_name}-vnet"
  address_space       = [var.vnet_address_space]
  location            = azurerm_resource_group.aks.location
  resource_group_name = azurerm_resource_group.aks.name

  lifecycle {
    ignore_changes = [
      tags["CreatedOnDate"],
      tags["mongodb_infosec_creator"],
    ]
  }
}

resource "azurerm_subnet" "aks" {
  name                 = "${var.cluster_name}-subnet"
  resource_group_name  = azurerm_resource_group.aks.name
  virtual_network_name = azurerm_virtual_network.aks.name
  address_prefixes     = [var.subnet_address_prefix]
}

resource "azurerm_network_security_group" "aks" {
  name                = "${var.cluster_name}-nsg"
  location            = azurerm_resource_group.aks.location
  resource_group_name = azurerm_resource_group.aks.name

  tags = merge(
    var.tags,
    {
      "CreatedBy"   = var.created_by
      "ExpiredOn"   = var.expired_on
      "ManagedBy"   = "Terraform"
      "Environment" = var.environment
    }
  )

  lifecycle {
    ignore_changes = [
      tags["CreatedOnDate"],
      tags["mongodb_infosec_creator"],
    ]
  }
}

resource "azurerm_subnet_network_security_group_association" "aks" {
  subnet_id                 = azurerm_subnet.aks.id
  network_security_group_id = azurerm_network_security_group.aks.id
}

resource "azurerm_network_security_rule" "ops_manager_8080" {
  count                       = length(var.ops_manager_allowed_cidrs) > 0 ? 1 : 0
  name                        = "Allow_OpsManager_8080"
  priority                    = 1000
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  source_address_prefixes     = var.ops_manager_allowed_cidrs
  destination_port_ranges     = ["8080"]
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.aks.name
  network_security_group_name = azurerm_network_security_group.aks.name
}

resource "azurerm_kubernetes_cluster" "aks" {
  name                = var.cluster_name
  location            = azurerm_resource_group.aks.location
  resource_group_name = azurerm_resource_group.aks.name
  dns_prefix          = var.dns_prefix

  default_node_pool {
    name                        = "default"
    node_count                  = var.node_count
    vm_size                     = var.vm_size
    vnet_subnet_id              = azurerm_subnet.aks.id
    temporary_name_for_rotation = "temp"
  }

  network_profile {
    network_plugin = "azure"
  }

  identity {
    type = "SystemAssigned"
  }

  oidc_issuer_enabled = true

  tags = merge(
    var.tags,
    {
      "CreatedBy"   = var.created_by
      "ExpiredOn"   = var.expired_on
      "ManagedBy"   = "Terraform"
      "Environment" = var.environment
    }
  )

  lifecycle {
    ignore_changes = [
      tags["CreatedOnDate"],
      tags["mongodb_infosec_creator"],
      default_node_pool[0].upgrade_settings,
    ]
  }
}
