resource "azurerm_network_interface" "bastion_nic" {
  count               = var.create ? 1 : 0
  name                = "${var.bastion_name}-nic"
  location            = var.location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = var.subnet_ids[var.vnet_subnet_name]
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.bastion_pip[0].id
  }
  tags = local.rendered_tags
}

resource "azurerm_public_ip" "bastion_pip" {
  count               = var.create ? 1 : 0
  name                = "${var.bastion_name}-pip"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags = local.rendered_tags
}

resource "azurerm_network_security_group" "bastion_nsg" {
  count               = var.create ? 1 : 0
  name                = "${var.bastion_name}-nsg"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags = local.rendered_tags
}

resource "azurerm_network_security_rule" "allow_ssh" {
  count                       = var.create ? 1 : 0
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
  network_security_group_name = azurerm_network_security_group.bastion_nsg[0].name
}

resource "azurerm_linux_virtual_machine" "bastion" {
  count               = var.create ? 1 : 0
  name                = var.bastion_name
  resource_group_name = var.resource_group_name
  location            = var.location
  size                = var.vm_size
  network_interface_ids = [
    azurerm_network_interface.bastion_nic[0].id
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

  disable_password_authentication = true
  admin_username                  = var.admin_username
  admin_ssh_key {
    username   = "azureuser"
    public_key = file(var.ssh_public_key_path)
  }

  custom_data = base64encode(templatefile("${path.module}/scripts/init.tpl", {
    kube_config_map = var.aks_kube_config_raw != "" ? { (var.aks_cluster_name) = var.aks_kube_config_raw } : {}
    admin_username  = var.admin_username
  }))
  tags = local.rendered_tags
}

resource "azurerm_network_interface_security_group_association" "bastion_nic_nsg" {
  count                       = var.create ? 1 : 0
  network_interface_id      = azurerm_network_interface.bastion_nic[0].id
  network_security_group_id = azurerm_network_security_group.bastion_nsg[0].id
}
