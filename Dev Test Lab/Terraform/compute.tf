resource "azurerm_dev_test_windows_virtual_machine" "lab" {
  count                  = var.lab_vm_count
  name                   = "${var.lab_vm_prefix}0${count.index+1}"
  lab_name               = azurerm_dev_test_lab.lab.name
  location               = azurerm_resource_group.lab.location
  resource_group_name    = azurerm_resource_group.lab.name
  size                   = var.lab_vm_size
  username               = "farouk"
  password               = "Pa$w0rd1234!"
  lab_virtual_network_id = azurerm_dev_test_virtual_network.lab.id
  lab_subnet_name        = azurerm_dev_test_virtual_network.lab.subnet[0].name
  storage_type           = "Standard"
  notes                  = "Some notes about this Virtual Machine."

  gallery_image_reference {
    publisher = "MicrosoftWindowsDesktop"
    offer     = "office-365"
    sku       = "19h2-evd-o365pp"
    version   = "latest"
  }
}