# Restoration design for the blueprint

## Problem

The blueprint is used in different resources s3, rds, dynamodb. It would be good to have the ability from the blueprint to run an automated test to validate that the restoration would work. Effectively we're testing a restoration process.

We want to add the ability to check the integrity of the restored resource that would be specific for the blueprint implementer. Eg. For an rds instance can we define an sql query that would test the integrity of the customers data. The customer would be responsible for defining that check and validating it is correct.
The step function would just allow this functionality to be defined and added by the user.

## Solution 1 - Step function

We're making the assumption that we are restoring from the destination account to the source account. Following are the steps for each resource type.

This implementation will make use of Step Functions and Lambdas to achieve the outcome. There is an option validation Lambda provided by the customer.

### S3

1. Kick off a restore on the restoration point, restoring to a **destination** S3 bucket
2. Copy from the **destiintion** S3 bucket to the **source** bucket
3. Run the customer's validation lambda, if provided

### RDS

## Solution 2


