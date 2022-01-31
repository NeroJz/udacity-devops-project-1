variable "prefix" {
  description = "The prefix which should be used for all resources in this example"
}

variable "location" {
  description = "The Azure Region in which all resources in this example should be created"
  default     = "East US"
}

variable "tags" {
  description = "The default tags used for the all resources"
  default = {
    "udacity" = "udacity-1st-devops-project"
  }
}

variable "packer_resource_group" {
  description = "The name of the resource group that the packer image located"
  default     = "udacity-project1-packer-rg"
}

variable "no_vms" {
  description = "The number of VM to be created"
  default     = 2
  type        = number
}


variable "username" {
  description = "The Admin User for the VM"
  default     = "azureAdmin"
}

variable "password" {
  description = "The Admin password for the VM"
}