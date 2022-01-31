provider "azurerm" {
  features {}
}

data "azurerm_image" "web" {
  name                = "myPackerImage"
  resource_group_name = var.packer_resource_group
}

resource "azurerm_resource_group" "main" {
  name     = "${var.prefix}-rg"
  location = var.location
  tags     = var.tags

}

resource "azurerm_virtual_network" "main" {
  name = "${var.prefix}-vNet"

  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location

  address_space = ["10.0.0.0/16"]

  tags = var.tags
}

resource "azurerm_subnet" "internal" {
  name = "internal"

  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name

  address_prefixes = ["10.0.2.0/24"]
}


resource "azurerm_network_security_group" "main" {
  name = "${var.prefix}-network-security-group"

  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location

  tags = var.tags
}

resource "azurerm_network_security_rule" "rule1" {
  name                        = "DenyAllInbound"
  description                 = "This rule deny all the inbound traffic from the internet"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "Internet"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.main.name
}

resource "azurerm_network_security_rule" "rule2" {
  name                        = "AllowInboundVMs"
  description                 = "This rule allows the inbound traffice inside the same virtual network"
  priority                    = 110
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_ranges          = ["0-1000"]
  destination_port_ranges     = ["0-1000"]
  source_address_prefix       = "VirtualNetwork"
  destination_address_prefix  = "VirtualNetwork"
  resource_group_name         = azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.main.name
}



resource "azurerm_network_security_rule" "rule3" {
  name                        = "AllowVnetOutBound"
  description                 = "Allow outbount traffic in the sameVirtual network"
  priority                    = 100
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_ranges          = ["0-1000"]
  destination_port_ranges     = ["0-1000"]
  source_address_prefix       = "VirtualNetwork"
  destination_address_prefix  = "VirtualNetwork"
  resource_group_name         = azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.main.name
}

resource "azurerm_network_security_rule" "rule4" {
  name                        = "AllowHTTPLB"
  description                 = "Allow http traffic to the VM from the load balancer"
  priority                    = 120
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_ranges          = ["0-1000"]
  destination_port_ranges     = ["0-1000"]
  source_address_prefix       = "AzureLoadBalancer"
  destination_address_prefix  = "VirtualNetwork"
  resource_group_name         = azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.main.name
}

resource "azurerm_network_interface" "main" {
  count = var.no_vms
  name  = "${var.prefix}-nic-${count.index}"

  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.internal.id
    private_ip_address_allocation = "Dynamic"
  }

  tags = var.tags
}

resource "azurerm_network_interface_security_group_association" "main" {
  count                     = var.no_vms
  network_interface_id      = azurerm_network_interface.main[count.index].id
  network_security_group_id = azurerm_network_security_group.main.id
}


resource "azurerm_public_ip" "main" {
  name = "${var.prefix}-public-ip"

  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  allocation_method   = "Static"

  tags = var.tags
}

resource "azurerm_lb" "main" {
  name = "${var.prefix}-lb"

  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location

  frontend_ip_configuration {
    name                 = "PublicIPAddress"
    public_ip_address_id = azurerm_public_ip.main.id
  }

  tags = var.tags
}

resource "azurerm_lb_backend_address_pool" "main" {
  name            = "${var.prefix}-lb-backend-address-pool"
  loadbalancer_id = azurerm_lb.main.id
}

resource "azurerm_network_interface_backend_address_pool_association" "main" {
  count                   = var.no_vms
  network_interface_id    = azurerm_network_interface.main[count.index].id
  ip_configuration_name   = "internal"
  backend_address_pool_id = azurerm_lb_backend_address_pool.main.id
}

resource "azurerm_availability_set" "main" {
  name                = "${var.prefix}-aset"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location

  tags = var.tags
}

resource "azurerm_managed_disk" "main" {
  count                = var.no_vms
  name                 = "${var.prefix}-managed-disk-${count.index}"
  location             = azurerm_resource_group.main.location
  resource_group_name  = azurerm_resource_group.main.name
  storage_account_type = "Standard_LRS"
  create_option        = "Empty"
  disk_size_gb         = "1"

  tags = var.tags
}



resource "azurerm_linux_virtual_machine" "main" {
  count = var.no_vms
  name  = "${var.prefix}-vm-${count.index}"

  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location

  size                            = "Standard_B1ls"
  admin_username                  = var.username
  admin_password                  = var.password
  disable_password_authentication = false
  network_interface_ids = [
    azurerm_network_interface.main[count.index].id
  ]
  availability_set_id = azurerm_availability_set.main.id

  source_image_id = data.azurerm_image.web.id

  os_disk {
    storage_account_type = "Standard_LRS"
    caching              = "ReadWrite"
  }

  tags = var.tags
}

resource "azurerm_virtual_machine_data_disk_attachment" "main" {
  count              = var.no_vms
  managed_disk_id    = element(azurerm_managed_disk.main.*.id, count.index)
  virtual_machine_id = element(azurerm_linux_virtual_machine.main.*.id, count.index)
  lun                = 1
  caching            = "ReadWrite"
}
