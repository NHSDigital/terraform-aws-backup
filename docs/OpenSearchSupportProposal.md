# Opensearch Support Proposal


## AWS Opensearch AWS Backup

Two solutions were investigated for managing AWS Opensearch across different AWS accounts, with a focus on data resiliency and disaster recovery (DR).

## Solution 1

(https://github.com/aws-samples/aws-cross-region-elasticsearch-backup-restore)

### Prerequiste

1. 2 accounts.
2. 2 Opensearch.
3. A shared S3 
4. Step function and lambda required for backup process

### Process

(The process is contained in the step function)
1. Initiate the snapshot.
2. Validate snapshot completion.
3. Restore snapshot in backup account.

#### Pros

1. Template solution is ready.
2. Faster recovery in disaster recovery situation.

#### Cons

1. Does not provide immutability backup that may be required in the disaster recovery situation.
2. Requires a second Opensearch service.
3. The shared S3 bucket may be comprised in a disaster recovery situation.

## Solution 2

### Prerequiste

1. S3 bucket specific for Opensearch index snapshots.
2. IAM role to allow for Opensearch to make manual snapshots to the S3 bucket.
3. Lambda to be triggered from event to kick off the manual snapshot.

### Process

1. Trigger lambda from event to call Opensearch API to create manual snapshot.
2. Opensearch (asynchoronously) will create a snapshot of the index and store the snapshot in S3.
3. Using existing functionality on the blueprint to create restoration points for S3 buckets and files.
4. Copy restoration point from source account to the backup account.

#### Pros

1. Use existing functionality surrounding S3 to create restoration points.
2. Allows snapshots to be recovered into a possible different AWS account in the event the source account is compromised.

#### Cons

1. Manual triggering of snapshot creation.
2. Failures in the lambda or the snapshot creation may error and custom handling may be required.


## Conclusion

The disaster recovery prerequiste requires an immutable backup of the index. Therefore the viable solution is to use Solution 2 which is based off the AWS Backup service.


## Restore Process

1. Copy restoration point from backup account to main account.
2. Trigger restore from restoration point to S3 bucket.
3. Trigger index restore from S3 bucket snapshot files.
