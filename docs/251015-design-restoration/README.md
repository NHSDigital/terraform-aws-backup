# Design of source vault restorations

## Tickets

* ENG-893
* ENG-921

## Summary

In dev vault step function definitions for code-ark-dev-automated-restore-test we can find an example step function. We need to create a new step function that will exist in the blueprint which will do the restoration process for S3, RDS, DynamoDB and Aurora.

It will include a Middleman Lambda function for calling the customer's Lambda for testing the restoration based on the customer's requirements and processing the results.

[ENG-893 Restoration Design Options](restoration-design.md)

Solution 1 was chosen.

## Step function design

![ENG-921 Step Function Design](<ENG-921 Step function for restorations from blueprint.drawio.png>)
