locals {
  tag_context_base            = merge(var.tag_globals, var.tag_context)
  bastion_nic_name            = "${var.bastion_name}-nic"
  bastion_pip_name            = "${var.bastion_name}-pip"
  bastion_nsg_name            = "${var.bastion_name}-nsg"
  rendered_tags_bastion_nic   = { for k, v in var.common_tags : k => replace(v, "/#\\{([^}]+)\\}/", lookup(merge(local.tag_context_base, { resource_name = local.bastion_nic_name }), try(regex("#\\{([^}]+)\\}", v)[0], ""), "")) }
  rendered_tags_bastion_pip   = { for k, v in var.common_tags : k => replace(v, "/#\\{([^}]+)\\}/", lookup(merge(local.tag_context_base, { resource_name = local.bastion_pip_name }), try(regex("#\\{([^}]+)\\}", v)[0], ""), "")) }
  rendered_tags_bastion_nsg   = { for k, v in var.common_tags : k => replace(v, "/#\\{([^}]+)\\}/", lookup(merge(local.tag_context_base, { resource_name = local.bastion_nsg_name }), try(regex("#\\{([^}]+)\\}", v)[0], ""), "")) }
  rendered_tags_bastion_vm    = { for k, v in var.common_tags : k => replace(v, "/#\\{([^}]+)\\}/", lookup(merge(local.tag_context_base, { resource_name = var.bastion_name }), try(regex("#\\{([^}]+)\\}", v)[0], ""), "")) }
}

resource "azurerm_network_interface" "bastion_nic" {
  count               = var.create ? 1 : 0
  name                = local.bastion_nic_name
  location            = var.location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = var.subnet_ids[var.vnet_subnet_name]
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.bastion_pip[0].id
  }
  tags = local.rendered_tags_bastion_nic
}

resource "azurerm_public_ip" "bastion_pip" {
  count               = var.create ? 1 : 0
  name                = local.bastion_pip_name
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags = local.rendered_tags_bastion_pip
}

resource "azurerm_network_security_group" "bastion_nsg" {
  count               = var.create ? 1 : 0
  name                = local.bastion_nsg_name
  location            = var.location
  resource_group_name = var.resource_group_name
  tags = local.rendered_tags_bastion_nsg
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

  identity {
    type = "SystemAssigned"
  }

  custom_data = base64encode(templatefile("${path.module}/scripts/init.tpl", {
    configure_kubectl   = var.configure_kubectl
    cluster_name       = var.cluster_name
    resource_group_name = var.resource_group_name
    admin_username     = var.admin_username
  }))
  tags = local.rendered_tags_bastion_vm
}

resource "azurerm_network_interface_security_group_association" "bastion_nic_nsg" {
  count                       = var.create ? 1 : 0
  network_interface_id      = azurerm_network_interface.bastion_nic[0].id
  network_security_group_id = azurerm_network_security_group.bastion_nsg[0].id
}
