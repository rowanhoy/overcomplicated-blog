variable "environment" {
    description = "environment to deploy to"
    type = string
    default = "dev"

    validation {
        condition = contains(["dev", "prod"], var.environment)
        error_message = "environment must be either dev or prod"
    }
}

variable "subscription_id" {
    description = "Azure subscription ID"
    type = string
    default = "615fafa0-b83c-4cf8-bc91-6e9ff4f3edca"
}

variable "app_name" {
    description = "Name of the app"
    type = string
    default = "overcomplicated-blog"
}

variable "app_name_simple" {
    description = "Name of the app without special characters"
    type = string
    default = "overcomplicatedblog"
}