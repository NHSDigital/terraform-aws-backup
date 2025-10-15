# Restoration Design for the Blueprint

## Problem

The blueprint is used to protect different AWS resource types (Amazon S3, Amazon RDS, Amazon DynamoDB). We want the ability to run an automated test to validate that restoration works—effectively testing the full restore process.

We also want to allow a blueprint implementer to define a custom integrity check for a restored resource. For example, for an RDS instance the user might provide an SQL query that validates the integrity of customer data. The customer is responsible for defining and maintaining the correctness of that check. The Step Function simply orchestrates invocation of the optional validation Lambda.

## Step Function

We assume we are copying from the **destination** account back to the **source** account and then restoring and testing within the **source** account. The high‑level steps are outlined per resource type.

This implementation uses AWS Step Functions and AWS Lambda. A customer-supplied (optional) validation Lambda may be invoked.

### Restoration Steps with Optional Validation Lambda

1. Copy the recovery point from the **destination** account to the **source** account (if required for cross‑account restore)
2. Initiate the restore from that recovery point (e.g. restoring to the **source** S3 bucket / RDS instance configuration / DynamoDB table)
3. Invoke the customer's validation Lambda, if provided

## Solution 1 – Customer-Managed Resources

Resources live in the customer's account. Access (e.g. security groups, networking details) is provided by the customer as input to the Step Function.

### S3 Requirements

* (Optional) Customer provides the ARN of a validation Lambda
* Customer defines the target bucket / prefix for the restored data (input to the Step Function)
* Customer provides the destination S3 bucket ARN as input

### RDS Requirements

* (Optional) Customer provides the ARN of a validation Lambda
* Customer defines where the restored RDS instance will reside
* Customer supplies all parameters required for the restore (e.g. subnet group, security groups, VPC, region, instance class, storage settings, engine version as needed)

### DynamoDB Requirements

* (Optional) Customer provides the ARN of a validation Lambda
* Customer provides the original (source) table name and (if different) the target table name
* Customer provides configuration inputs (as required): encryption (KMS key ARN if using a customer managed key), point‑in‑time recovery requirement
* Edge considerations: very large tables may require sampling; the validation Lambda should avoid full scans unless explicitly intended (respect 1 MB pagination limits and consistency model)

## Solution 2 – Internally Managed VPC Resources

Resources live within our managed VPC. The customer may provide a validation Lambda ARN; we configure the IAM permissions granting it access only to the restored resources. We supply resource identifiers as input to the validation Lambda.

### S3 Requirements

* (Optional) Customer provides the ARN of a validation Lambda
* We provide (as Lambda input) the restored S3 bucket ARN (and optionally object key prefix)

### RDS Requirements

* (Optional) Customer provides the ARN of a validation Lambda
* We provide the restored RDS instance identifiers (endpoint, ARN) as Lambda input and grant required read/connect permissions

### DynamoDB Requirements

* (Optional) Customer provides the ARN of a validation Lambda
* We pass (as Lambda input): restored table name/ARN, region
* Edge considerations: very large tables may require sampling; the validation Lambda should avoid full table scans unless explicitly intended (consider pagination and cost)
