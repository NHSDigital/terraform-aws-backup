# Immutable and Air-Gapped ECR Backup Solution

This document outlines a robust solution for creating immutable backups of Amazon ECR container images. The approach leverages a combination of custom scripting, Amazon S3, and AWS Backup to provide an air-gapped, cross-account disaster recovery strategy that is resilient to account compromise.

Why an Immutable ECR Backup?
While Amazon ECR provides image replication, it lacks an immutable, long-term backup solution in a separate security boundary. In a disaster recovery (DR) scenario where a primary AWS account is compromised, standard replication is not sufficient. This solution addresses that by creating an "air-gapped" backup protected by an AWS Backup Vault Lock, which provides a Write-Once-Read-Many (WORM) model.

## Solution Architecture

The solution consists of three main stages:

* Stage 1: ECR-to-S3 Backup: A scheduled process backs up container images from ECR to a source S3 bucket.
* Stage 2: Cross-Account Backup: AWS Backup automates the process of copying the S3 backups to a separate, dedicated "backup account."
* Stage 3: Immutable Vault Lock: An AWS Backup Vault Lock is applied to the destination vault, making the backups immutable for a defined period.

## Step-by-Step Implementation

### Stage 1: ECR to S3 Backup

This stage involves creating a scheduled Lambda function that pulls images from ECR and pushes them to an S3 bucket. The steps are as follows:
1. Schedule event is triggered (e.g., daily) using Amazon EventBridge.
2. The schedule event triggers an AWS Lambda function.
3. The Lambda function lists all repositories in the ECR registry.
4. For each repository, the function lists all image tags.
5. For each image tag (or a subsection of tags), the function pulls the image using the Docker CLI.
6. The function then pushes the image to a designated S3 bucket in the source account, organizing images by repository and tag for easy retrieval.


### Stage 2: Cross-Account Backup with AWS Backup

This functionality already exists in the existing blueprint solution.

### Stage 3: Enable Immutability with Vault Lock

This functionality already exists in the existing blueprint solution.

## Summary of Benefits

Immutability: The AWS Backup Vault Lock in Compliance mode ensures your backups cannot be tampered with.
Air-Gapped Security: Backups are stored in a separate AWS account, isolating them from any compromise of your production environment.
Centralized Management: AWS Backup handles the scheduling, retention, and lifecycle management of your S3 backups.
Cost-Effective: Only the objects in the S3 bucket are backed up, and AWS Backup automatically transitions older recovery points to a more cost-effective cold storage tier.


## Alternative Solution

ECR does provide cross-account replication, which can be used as a simpler alternative to this solution. However, it does not provide the same level of immutability and air-gapped security as the proposed solution. If you choose to use ECR replication, ensure that you have appropriate lifecycle policies and access controls in place to protect your images.

### Steps to set up ECR replication:

1. In the source account, create a replication rule to publish to the vault account.
2. In the destination account, create a repository to receive the replicated images.
3. Ensure that the IAM roles and policies are correctly configured to allow replication between accounts.
4. Implement lifecycle policies to manage the retention and deletion of images in the destination account.

### Considerations

* ECR replication does not provide immutability; images can be deleted or overwritten.
