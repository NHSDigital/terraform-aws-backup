# AWS Services Covered by the Backup Blueprint

This blueprint currently supports (and is validated against) the following AWS services via AWS Backup. Resources are selected for backup using the `NHSE-Enable-Backup = True` tag unless otherwise noted.

| Service | Included Scope | Notes & Caveats |
|---------|----------------|-----------------|
| Amazon S3 | Versioned buckets (all objects & versions) | Bucket versioning must be enabled. Consider lifecycle rules to prune noncurrent versions to control cost. |
| Amazon RDS (including Aurora) | Instance & cluster snapshots | Ensure automated backups are enabled where PITR is required. Aurora is treated under the RDS umbrella. |
| Amazon DynamoDB | Point-in-time recovery (PITR) + on-demand backups | PITR must be enabled on tables you tag. Large tables may create longer restore times; adjust retention to balance cost. |
| Amazon EBS | Snapshots of tagged volumes | Encrypt volumes (CMK or AWS-managed). Snapshot costs scale with changed blocks; monitor for high churn. |

## Operational Recommendations

- Test restores regularly (at an interval shorter than your shortest retention period) to surface latent issues and ransomware dwell time.
- Track cost drivers: large DynamoDB tables, high-churn EBS volumes, or buckets with many noncurrent versions can materially increase spend.
- Align retention with Information Asset Owner guidance; provided example values are intentionally short and will likely fail compliance framework checks in production.

---
If you spot inaccuracies, missing clarifications, or need another service, please raise an issue or open a PR.
