variable "source_account_name" {
  description = "The name of the account that backups will come from"
  type        = string
}

variable "source_account_id" {
  description = "The id of the account that backups will come from"
  type        = string
}

variable "account_id" {
  description = "The id of the account that the vault will be in"
  type        = string
}

variable "region" {
  description = "The region we should be operating in"
  type        = string
  default     = "eu-west-2"
}

variable "kms_key" {
  description = "The KMS key used to secure the vault"
  type        = string
}

variable "enable_vault_protection" {
  description = "Flag which controls if the vault lock is enabled"
  type        = bool
  default     = false
}

variable "vault_lock_type" {
  description = "The type of lock that the vault should be, will default to governance"
  type        = string
  # See toplevel README.md:
  #   DO NOT SET THIS TO compliance UNTIL YOU ARE SURE THAT YOU WANT TO LOCK THE VAULT PERMANENTLY
  default     = "governance"
}

variable "vault_lock_min_retention_days" {
  description = "The minimum retention period that the vault retains its recovery points"
  type        = number
  default     = 365
}

variable "vault_lock_max_retention_days" {
  description = "The maximum retention period that the vault retains its recovery points"
  type        = number
  default     = 365
}

variable "changeable_for_days" {
  description = "How long you want the vault lock to be changeable for, only applies to compliance mode. This value is expressed in days no less than 3 and no greater than 36,500; otherwise, an error will return."
  type        = number
  default     = 14
}
