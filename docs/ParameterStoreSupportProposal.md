# Parameter Store Support Proposal


## Cross-Account Parameter Store Sharing and Backup Solutions

Two solutions were investigated for managing AWS Systems Manager Parameter Store values across different AWS accounts, with a focus on data resiliency and disaster recovery (DR).

---

### Solution 1: AWS Parameter Store Cross-Account Sharing

This approach uses the built-in feature to share Advanced Parameter Store parameters to other accounts via AWS Resource Access Manager (RAM).

| Category | Pros (Advantages) | Cons (Disadvantages) |
| :--- | :--- | :--- |
| **Simplicity** | **Built-in Functionality:** Quicker to set up and deploy as it uses native AWS services (SSM and RAM), requiring no custom code. | **Not a True Backup (No Immutability):** Does **not** create an isolated copy. The destination account reads the live parameter, meaning any change, deletion, or corruption in the source account is immediately reflected, undermining DR requirements. |
| **Management** | **Centralized Source of Truth:** Parameters are managed and updated in a single, central account, simplifying configuration management. | **Dependency and Coupling:** The consuming account is tightly dependent on the source account's availability and continued sharing configuration. |
| **Security/DR** | **Simplified Access:** Eliminates the need for complex cross-account IAM role assumption boilerplate code for applications to retrieve the parameter. | **Control Risk:** The sharing mechanism can be **turned off** at the source account at any time (via RAM), immediately breaking the consuming applications in the destination account. |

---

### Solution 2: Custom Lambda Backup to S3 with AWS Backup Replication

This is a custom-engineered solution to create an "air-gapped" backup of Parameter Store values, leveraging S3 and the immutability features of AWS Backup.

#### Pros (Advantages)

| Advantage | Description |
| :--- | :--- |
| **True Air-Gapped Backup** | This is the primary benefit. The solution creates a physically separate, isolated copy of the data, which is essential for comprehensive disaster recovery planning and protection against a compromise of the source account. |
| **Data Immutability** | By utilizing the existing AWS Backup functionality (which can leverage features like **Vault Lock**), the copy replicated to the destination account is made unchangeable for a defined period, safeguarding against accidental or malicious deletion. |
| **Decryption Key Isolation** | The **KMS key is controlled and stored on the destination account**. The source account only has permission to **encrypt** the data, ensuring the source cannot decrypt the backup, thereby enhancing security and control for the destination/DR team. |

#### Cons (Disadvantages)

| Disadvantage | Description |
| :--- | :--- |
| **Custom Maintenance Overhead** | Requires developing, deploying, and maintaining custom resources, including a **Lambda function** and all associated roles and permissions. This is a non-trivial manual backup solution. |
| **Consumer Upgrade Required** | If this solution is distributed via a standardized infrastructure blueprint, any bug fix or enhancement to the Lambda function or S3 configuration would necessitate a mandatory **upgrade of the entire blueprint** for all consuming accounts. |
| **Setup Complexity** | Requires complex, carefully configured cross-account permissions for the Lambda execution role, S3 bucket policy, and most critically, the **KMS key policy** to allow the source account to encrypt data using the destination account's key. |

#### More Detail on Solution 2 Steps

1.  **KMS Key Creation (Destination Account):** Create a KMS key on the destination account with a key policy that grants the source account's IAM role the specific permissions for `kms:Encrypt` and `kms:Decrypt`.
2.  **Lambda Trigger and Execution (Source Account):**
    * Create an event source (e.g., EventBridge scheduled rule) to trigger a Lambda function.
    * The Lambda function retrieves all parameter values from the Parameter Store path(s).
    * It then encrypts the contents using the **Destination Account's KMS key ARN**.
    * Finally, it stores the encrypted content as an object in an S3 bucket in the source account.
3.  **AWS Backup Integration (Source and Destination Accounts):**
    * A defined S3 bucket is added to an AWS Backup Plan.
    * The Backup Plan is configured to create a restoration point of the S3 bucket.
    * A **Copy Rule** within the Backup Plan is set up to replicate this restoration point to a **Backup Vault** in the destination account, completing the air-gapped data transfer.


#### Restoration Process Solution 2

1. Restoration is initiated from the source account, through a step function to run multiple restoration steps.
2. The restoration point is copied from the destination account's Backup Vault to the source account's Backup vault.
3. Restore the S3 object from the source account's Backup vault to the source account's S3 bucket.
4. Run Lambda function to restore from the S3 object to Parameter Store using the Destination account KMS key.
