locals {
  copy_targets = coalescelist(
    var.copy_target_arn_list,
    ["arn:aws:backup:${var.region}:${var.source_account_id}:backup-vault:${var.region}-${var.source_account_id}-backup-vault"]
  )
}