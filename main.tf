terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = "4.15.0"
    }
  }
}

provider "azurerm" {
    features {}
    subscription_id = var.subscription_id
}

resource "azurerm_resource_group" "main" {
  name     = "odzd-project-resource-group"
  location = "East US"
}

resource "azurerm_virtual_network" "main" {
  name                = "odzd-project-vnet"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "main" {
  name                 = "odzd-project-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_network_interface" "main" {
  name                = "odzd-project-nic"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.main.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.main.id
  }
}

resource "azurerm_network_security_group" "nsg" {
  name                = "odzd-project-network-security-group"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  
  security_rule {
    name                       = "SSH"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "HTTP3000"
    priority                   = 201
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3000"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "HTTP9090"
    priority                   = 202
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "9090"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "mongo27017"
    priority                   = 203
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "27017"
    source_address_prefix      = "83.5.253.253/32"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "mongoexporter9216"
    priority                   = 204
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "9216"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_interface_security_group_association" "my-nsg-assoc" {
  network_interface_id      = azurerm_network_interface.main.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

resource "azurerm_public_ip" "main" {
  name                = "odzd-project-pip"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
}



resource "azurerm_linux_virtual_machine" "main" {
  name                = "odzd-project-vm"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  size                = "Standard_B1s"
  admin_username      = "azureuser"

  network_interface_ids = [azurerm_network_interface.main.id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }

  admin_ssh_key {
    username   = "azureuser"
    public_key = file("~/.ssh/id_rsa.pub")
  }


  tags = {
    environment = "Development"
  }

  provisioner "local-exec" {
    command = <<EOT
      ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i "${azurerm_public_ip.main.ip_address}," -u azureuser --private-key ~/.ssh/id_rsa prometheus_grafana_playbook.yml
      ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i "${azurerm_public_ip.main.ip_address}," -u azureuser --private-key ~/.ssh/id_rsa upload_data_to_db_playbook.yml
      ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i "${azurerm_public_ip.main.ip_address}," -u azureuser --private-key ~/.ssh/id_rsa exporter_install_playbook.yml
    EOT
  }
}
