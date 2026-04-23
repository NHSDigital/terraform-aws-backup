# There can be only one [framework with x controls in one account]!
#
# For the frameworks of the other envs in the account, we "import"
# them using a `data` record, looking for the environment name set
# in the `resources_in_same_account` variable.

data "aws_backup_framework" "main" {
  count = var.backup_plan_config.enable && var.resources_in_same_account != "" ? 1 : 0
  name = replace("${var.name_prefix}-${var.resources_in_same_account}-framework", "-", "_")
}
resource "aws_backup_framework" "main" {
  count = var.backup_plan_config.enable && var.resources_in_same_account == "" ? 1 : 0

  # must be underscores instead of dashes
  name        = replace("${local.resource_name_prefix}-framework", "-", "_")
  description = "${var.project_name} Backup Framework"

  # Evaluates if recovery points are encrypted.
  control {
    name = "BACKUP_RECOVERY_POINT_ENCRYPTED"

    scope {
      tags = {
        "environment_name" = var.environment_name
      }
    }
  }

  /* Some explanation of BACKUP_RECOVERY_POINT_MANUAL_DELETION_DISABLED:

  The `principalArnList` input parameter is used to specify the IAM principals
  that are allowed to delete backups.  Creating the control without this input
  parameter gives you a control that says nobody is allowed to delete backups.
  But if you just pass in an empty list to the input_parameter, it will get
  rejected as invalid.

  That means we need a dynamic block around the input parameter itself to do
  the right thing if the user genuinely wants the set of principals allowed to
  delete backups to be empty, and to specify that by passing in the empty list
  as the `deletion_enabled_arn_list` variable.

  If the user does not want any principals to be blocked from deleting backups,
  they can not set the `deletion_enabled_arn_list` variable at all.  So we need
  a dynamic block around the control itself.  That matches what's currently
  deployed in teams, so we can publish the change without breaking
  existing deployments.
  */
  dynamic "control" {
    for_each = var.deletion_allowed_principal_arns != null ? [1] : []
    content {
      name = "BACKUP_RECOVERY_POINT_MANUAL_DELETION_DISABLED"

      scope {
        tags = {
          "environment_name" = var.environment_name
        }
      }

      dynamic "input_parameter" {
        for_each = length(var.deletion_allowed_principal_arns) > 0 ? [1] : []
        content {
          name  = "principalArnList"
          value = join(",", var.deletion_allowed_principal_arns)
        }
      }
    }
  }

  # Evaluates if recovery point retention period is at least 1 month.
  control {
    name = "BACKUP_RECOVERY_POINT_MINIMUM_RETENTION_CHECK"

    scope {
      tags = {
        "environment_name" = var.environment_name
      }
    }

    input_parameter {
      name  = "requiredRetentionDays"
      value = "35"
    }
  }

  # Evaluates if backup plan creates backups at least every 1 day and retains them for at least 1 month before deleting them.
  control {
    name = "BACKUP_PLAN_MIN_FREQUENCY_AND_MIN_RETENTION_CHECK"

    scope {
      tags = {
        "environment_name" = var.environment_name
      }
    }

    input_parameter {
      name  = "requiredFrequencyUnit"
      value = "days"
    }

    input_parameter {
      name  = "requiredRetentionDays"
      value = "35"
    }

    input_parameter {
      name  = "requiredFrequencyValue"
      value = "1"
    }
  }

  # Evaluates if resources are protected by a backup plan.
  control {
    name = "BACKUP_RESOURCES_PROTECTED_BY_BACKUP_PLAN"

    scope {
      compliance_resource_types = var.backup_plan_config.compliance_resource_types
      tags = {
        (var.backup_plan_config.selection_tag) = var.backup_plan_config.selection_tag_value != null ? var.backup_plan_config.selection_tag_value : "True"
      }
    }
  }

  # Evaluates if resources have at least one recovery point created within the past 1 day.
  control {
    name = "BACKUP_LAST_RECOVERY_POINT_CREATED"

    input_parameter {
      name  = "recoveryPointAgeUnit"
      value = "days"
    }

    input_parameter {
      name  = "recoveryPointAgeValue"
      value = "1"
    }

    scope {
      compliance_resource_types = var.backup_plan_config.compliance_resource_types
      tags = {
        (var.backup_plan_config.selection_tag) = var.backup_plan_config.selection_tag_value != null ? var.backup_plan_config.selection_tag_value : "True"
      }
    }
  }
}

data "aws_backup_framework" "dynamodb" {
  count = var.backup_plan_config_dynamodb.enable && var.resources_in_same_account != "" ? 1 : 0
  name = replace("${var.name_prefix}-${var.resources_in_same_account}-dynamodb-framework", "-", "_")
}
resource "aws_backup_framework" "dynamodb" {
  count = var.backup_plan_config_dynamodb.enable && var.resources_in_same_account == "" ? 1 : 0
  # must be underscores instead of dashes
  name        = replace("${local.resource_name_prefix}-dynamodb-framework", "-", "_")
  description = "${var.project_name} DynamoDB Backup Framework"

  # Evaluates if resources are protected by a backup plan.
  control {
    name = "BACKUP_RESOURCES_PROTECTED_BY_BACKUP_PLAN"

    scope {
      compliance_resource_types = var.backup_plan_config_dynamodb.compliance_resource_types
      tags = {
        (var.backup_plan_config_dynamodb.selection_tag) = var.backup_plan_config_dynamodb.selection_tag_value != null ? var.backup_plan_config_dynamodb.selection_tag_value : "True"
      }
    }
  }

  # Evaluates if resources have at least one recovery point created within the past 1 day.
  control {
    name = "BACKUP_LAST_RECOVERY_POINT_CREATED"

    input_parameter {
      name  = "recoveryPointAgeUnit"
      value = "days"
    }

    input_parameter {
      name  = "recoveryPointAgeValue"
      value = "1"
    }

    scope {
      compliance_resource_types = var.backup_plan_config_dynamodb.compliance_resource_types
      tags = {
        (var.backup_plan_config_dynamodb.selection_tag) = var.backup_plan_config_dynamodb.selection_tag_value != null ? var.backup_plan_config_dynamodb.selection_tag_value : "True"
      }
    }
  }
}

data "aws_backup_framework" "ebsvol" {
  count = var.backup_plan_config_ebsvol.enable && var.resources_in_same_account != "" ? 1 : 0
  name = replace("${var.name_prefix}-${var.resources_in_same_account}-ebsvol-framework", "-", "_")
}
resource "aws_backup_framework" "ebsvol" {
  count = var.backup_plan_config_ebsvol.enable && var.resources_in_same_account == "" ? 1 : 0
  # must be underscores instead of dashes
  name        = replace("${local.resource_name_prefix}-ebsvol-framework", "-", "_")
  description = "${var.project_name} EBS Backup Framework"

  # Evaluates if resources are protected by a backup plan.
  control {
    name = "BACKUP_RESOURCES_PROTECTED_BY_BACKUP_PLAN"

    scope {
      compliance_resource_types = var.backup_plan_config_ebsvol.compliance_resource_types
      tags = {
        (var.backup_plan_config_ebsvol.selection_tag) = "True"
      }
    }
  }

  # Evaluates if resources have at least one recovery point created within the past 1 day.
  control {
    name = "BACKUP_LAST_RECOVERY_POINT_CREATED"

    input_parameter {
      name  = "recoveryPointAgeUnit"
      value = "days"
    }

    input_parameter {
      name  = "recoveryPointAgeValue"
      value = "1"
    }

    scope {
      compliance_resource_types = var.backup_plan_config_ebsvol.compliance_resource_types
      tags = {
        (var.backup_plan_config_ebsvol.selection_tag) = "True"
      }
    }
  }
}

data "aws_backup_framework" "aurora" {
  count = var.backup_plan_config_aurora.enable && var.resources_in_same_account != "" ? 1 : 0
  name = replace("${var.name_prefix}-${var.resources_in_same_account}-aurora-framework", "-", "_")
}
resource "aws_backup_framework" "aurora" {
  count = var.backup_plan_config_aurora.enable && var.resources_in_same_account == "" ? 1 : 0
  # must be underscores instead of dashes
  name        = replace("${local.resource_name_prefix}-aurora-framework", "-", "_")
  description = "${var.project_name} Aurora Backup Framework"

  # Evaluates if resources are protected by a backup plan.
  control {
    name = "BACKUP_RESOURCES_PROTECTED_BY_BACKUP_PLAN"

    scope {
      compliance_resource_types = var.backup_plan_config_aurora.compliance_resource_types
      tags = {
        (var.backup_plan_config_aurora.selection_tag) = "True"
      }
    }
  }
  # Evaluates if resources have at least one recovery point created within the past 1 day.
  control {
    name = "BACKUP_LAST_RECOVERY_POINT_CREATED"

    input_parameter {
      name  = "recoveryPointAgeUnit"
      value = "days"
    }

    input_parameter {
      name  = "recoveryPointAgeValue"
      value = "1"
    }

    scope {
      compliance_resource_types = var.backup_plan_config_aurora.compliance_resource_types
      tags = {
        (var.backup_plan_config_aurora.selection_tag) = "True"
      }
    }
  }
}

data "aws_backup_framework" "parameter_store" {
  count = var.backup_plan_config_parameter_store.enable && var.resources_in_same_account != "" ? 1 : 0
  name = replace("${var.name_prefix}-${var.resources_in_same_account}-parameter-store-framework", "-", "_")
}
resource "aws_backup_framework" "parameter_store" {
  count = var.backup_plan_config_parameter_store.enable && var.resources_in_same_account == "" ? 1 : 0
  # must be underscores instead of dashes
  name        = replace("${local.resource_name_prefix}-parameter-store-framework", "-", "_")
  description = "${var.project_name} Parameter Store Backup Framework"

  # Evaluates if resources are protected by a backup plan.
  control {
    name = "BACKUP_RESOURCES_PROTECTED_BY_BACKUP_PLAN"

    scope {
      compliance_resource_types = ["S3"]
      tags = {
        (var.backup_plan_config_parameter_store.selection_tag) = "True"
      }
    }
  }
  # Evaluates if resources have at least one recovery point created within the past 1 day.
  control {
    name = "BACKUP_LAST_RECOVERY_POINT_CREATED"

    input_parameter {
      name  = "recoveryPointAgeUnit"
      value = "days"
    }

    input_parameter {
      name  = "recoveryPointAgeValue"
      value = "1"
    }

    scope {
      compliance_resource_types = ["S3"]
      tags = {
        (var.backup_plan_config_parameter_store.selection_tag) = "True"
      }
    }
  }
}

# -----

moved {
  from = aws_backup_framework.main
  to   = aws_backup_framework.main[0]
}
