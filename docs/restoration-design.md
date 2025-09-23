# Restoration design for the blueprint

## Problem

The blueprint is used in different resources s3, rds, dynamodb. It would be good to have the ability from the blueprint to run an automated test to validate that the restoration would work. Effectively we're testing a restoration process.

We want to add the ability to check the integrity of the restored resource that would be specific for the blueprint implementer. Eg. For an rds instance can we define an sql query that would test the integrity of the customers data. The customer would be responsible for defining that check and validating it is correct.
The step function would just allow this functionality to be defined and added by the user.

## Proposed solution - Step Function

We're making the assumption that we are restoring from the **destination** account to the **source** account. Following are the steps for each resource type.

This implementation will make use of Step Functions and Lambdas to achieve the outcome. There is an option validation Lambda provided by the customer.

### Restoration steps with Lambda validation

1. Copy the restoration point from the **destination** to the **source**
2. Kick off a restore on the restoration point, restoring to the **source** S3 bucket
3. Run the customer's validation lambda, if provided

## Resource Solution 1 - customer managed resources

Resources live in the customer space and access is provided by the customer and the security groups are provided as input to the step function.

### S3 requirements

* Customer should optionally provide the ARN to a Lambda for validation
* Customer should define where we are pushing the restoration to as an input to the step function
* Customer's S3 bucket ARN provided as input to Step Function

### RDS requirements

* Customer should optionally provide the ARN to a Lambda for validation
* Customer should define where the RDS instance will be located
* The input provided will be everything required to restore an RDS instance (e.g. subnet, security group, VPC, region)

### DynamoDB requirements

* Customer should optionally provide the ARN to a Lambda for validation
* Customer provides the original (source) table name to restore into
* Customer provides configuration inputs: KMS key ARN if using a customer managed key

Edge considerations: very large tables may require sampling; customer-owned Lambda should avoid full table scans unless explicitly intended (note possible 1 MB pagination limits, eventual vs. consistent reads)

## Resource Solution 2 - VPC internally managed resources

Resources live within a our configured VPC and the customer must provide their Lambda ARN and we configure the permissions for it to access the resources. We would push details of the resources to validate against as input to the Lambda validation function.

### S3 requirements

* Customer should optionally provide the ARN to a Lambda for validation
* We will provide, as input to the customer's Lambda, the ARN of the S3 bucket

### RDS requirements

* Customer should optionally provide the ARN to a Lambda for validation
* We will provide access to the RDS to the customer's Lambda.

### DynamoDB requirements

* Customer should optionally provide the ARN to a Lambda for validation
* We pass to the validation Lambda as input: restored table name/ARN, region

Edge considerations: very large tables may require sampling; customer-owned Lambda should avoid full table scans unless explicitly intended (note possible 1 MB pagination limits, eventual vs. consistent reads)
