locals {
  # Convert the values to terraform templates.
  common_tags = {
    for key, value in var.common_tags :
    key => replace(value, "/@\\{([^}]+)\\}/", "$${$1}")
  }
}

resource "azurerm_network_interface" "bastion_nic" {
  name                = "${var.bastion_name}-nic"
  location            = var.location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = var.subnet_ids[var.vnet_subnet_name]
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.bastion_pip.id
  }
  tags = {
    for key, value in local.common_tags :
    key => templatestring(value, {
      resource_name  = "${var.bastion_name}-nic"
      location       = var.location
      resource_group = var.resource_group_name
      environment    = var.environment
    })
  }
}

resource "azurerm_public_ip" "bastion_pip" {
  name                = "${var.bastion_name}-pip"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags = {
    for key, value in local.common_tags :
    key => templatestring(value, {
      resource_name  = "${var.bastion_name}-pip"
      location       = var.location
      resource_group = var.resource_group_name
      environment    = var.environment
    })
  }
}

resource "azurerm_network_security_group" "bastion_nsg" {
  name                = "${var.bastion_name}-nsg"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags = {
    for key, value in local.common_tags :
    key => templatestring(value, {
      resource_name  = "${var.bastion_name}-nsg"
      location       = var.location
      resource_group = var.resource_group_name
      environment    = var.environment
    })
  }
}

resource "azurerm_network_security_rule" "allow_ssh" {
  name                        = "allow-ssh"
  priority                    = 1001
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.bastion_nsg.name
}

resource "azurerm_linux_virtual_machine" "bastion" {
  name                = var.bastion_name
  resource_group_name = var.resource_group_name
  location            = var.location
  size                = var.vm_size
  network_interface_ids = [
    azurerm_network_interface.bastion_nic.id
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    name                 = "${var.bastion_name}-osdisk"
  }

  source_image_reference {
    publisher = "Debian"
    offer     = "debian-11"
    sku       = "11"
    version   = "latest"
  }

  computer_name = var.bastion_name

  # TODO: Using browser-based RDP/SSH? or ENTRA-ID
  disable_password_authentication = true
  admin_username                  = var.admin_username
  admin_ssh_key {
    username   = "azureuser"
    public_key = file(var.ssh_public_key_path)
  }

  custom_data = base64encode(templatefile("${path.module}/scripts/init.tpl", {
    kube_config_map = { (var.aks_cluster_name) = var.aks_kube_config_raw}
    admin_username  = var.admin_username
  }))
  tags = {
    for key, value in local.common_tags :
    key => templatestring(value, {
      resource_name  = var.bastion_name
      location       = var.location
      resource_group = var.resource_group_name
      environment    = var.environment
    })
  }
}

resource "azurerm_network_interface_security_group_association" "bastion_nic_nsg" {
  network_interface_id      = azurerm_network_interface.bastion_nic.id
  network_security_group_id = azurerm_network_security_group.bastion_nsg.id
}
