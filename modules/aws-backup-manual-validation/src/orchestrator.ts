/* Orchestrator Lambda (TypeScript)
   Triggers a manual restore job for a chosen recovery point and invokes a customer-provided validation Lambda.
   The customer Lambda should return JSON: { status: "SUCCESSFUL|FAILED|SKIPPED", message: string }
*/
import { BackupClient, ListRecoveryPointsByBackupVaultCommand, StartRestoreJobCommand, DescribeRestoreJobCommand, PutRestoreValidationResultCommand } from "@aws-sdk/client-backup";
import { LambdaClient, InvokeCommand } from "@aws-sdk/client-lambda";
import { S3Client, HeadObjectCommand } from "@aws-sdk/client-s3";

const backup = new BackupClient({});
const lambda = new LambdaClient({});
const s3 = new S3Client({});

const BACKUP_VAULT_NAME = process.env.BACKUP_VAULT_NAME!;
const RESOURCE_TYPE = process.env.RESOURCE_TYPE!; // e.g. S3
const VALIDATOR_LAMBDA = process.env.VALIDATOR_LAMBDA!;
const TARGET_BUCKET = process.env.TARGET_BUCKET; // optional S3 bucket

interface ValidatorResult { status: string; message?: string; [k: string]: any }

export const handler = async (event: any = {}): Promise<any> => {
  console.log(JSON.stringify({ msg: "Manual restore orchestration start", event }));

  const recoveryPointArn = event.recoveryPointArn || await pickLatestRecoveryPoint();
  console.log({ recoveryPointArn });

  const restoreJobId = await startRestore(recoveryPointArn);
  console.log({ restoreJobId });

  const restoreDesc = await waitForCompletion(restoreJobId);
  console.log({ restoreDesc });

  const validatorPayload = {
    restoreJobId,
    recoveryPointArn,
    resourceType: RESOURCE_TYPE,
    createdResourceArn: restoreDesc.CreatedResourceArn,
    targetBucket: TARGET_BUCKET,
    // Additional S3 example context the customer validator might use:
    s3: { bucket: TARGET_BUCKET }
  };

  const validationResult = await invokeValidator(validatorPayload);
  console.log({ validationResult });

  await publishValidation(restoreJobId, validationResult);

  return {
    restoreJobId,
    recoveryPointArn,
    validation: validationResult
  };
};

async function pickLatestRecoveryPoint(): Promise<string> {
  const cmd = new ListRecoveryPointsByBackupVaultCommand({ BackupVaultName: BACKUP_VAULT_NAME, MaxResults: 20 });
  const resp = await backup.send(cmd);
  if (!resp.RecoveryPoints || resp.RecoveryPoints.length === 0) {
    throw new Error("No recovery points found in vault");
  }
  // Sort by CreationDate descending
  const sorted = [...resp.RecoveryPoints].sort((a, b) => (b.CreationDate?.getTime() || 0) - (a.CreationDate?.getTime() || 0));
  return sorted[0].RecoveryPointArn!;
}

async function startRestore(recoveryPointArn: string): Promise<string> {
  // For S3 we can do a metadata-only restore or specify a placeholder
  const cmd = new StartRestoreJobCommand({
    RecoveryPointArn: recoveryPointArn,
    IamRoleArn: process.env.RESTORE_ROLE_ARN,
    ResourceType: RESOURCE_TYPE,
    Metadata: TARGET_BUCKET ? { destinationBucketName: TARGET_BUCKET } : {}
  });
  const resp = await backup.send(cmd);
  if (!resp.RestoreJobId) throw new Error("StartRestoreJob returned no RestoreJobId");
  return resp.RestoreJobId;
}

async function waitForCompletion(restoreJobId: string) {
  const timeoutMs = 1000 * 60 * 55; // 55 minutes safety
  const start = Date.now();
  while (Date.now() - start < timeoutMs) {
    const desc = await backup.send(new DescribeRestoreJobCommand({ RestoreJobId: restoreJobId }));
    if (desc.Status === "COMPLETED" || desc.Status === "ABORTED" || desc.Status === "FAILED") {
      return desc;
    }
    await new Promise(r => setTimeout(r, 15000));
  }
  throw new Error("Restore job did not finish within timeout");
}

async function invokeValidator(payload: any): Promise<ValidatorResult> {
  const cmd = new InvokeCommand({
    FunctionName: VALIDATOR_LAMBDA,
    InvocationType: "RequestResponse",
    Payload: Buffer.from(JSON.stringify(payload))
  });
  const resp = await lambda.send(cmd);
  if (!resp.Payload) throw new Error("Validator returned no payload");
  const txt = Buffer.from(resp.Payload).toString("utf-8");
  try {
    return JSON.parse(txt);
  } catch (e) {
    throw new Error("Validator payload JSON parse error: " + txt);
  }
}

async function publishValidation(restoreJobId: string, result: ValidatorResult) {
  const status = mapStatus(result.status);
  const message = (result.message || "").slice(0, 1000);
  const cmd = new PutRestoreValidationResultCommand({
    RestoreJobId: restoreJobId,
    ValidationStatus: status,
    ValidationStatusMessage: message
  });
  await backup.send(cmd);
}

function mapStatus(s?: string): string {
  if (!s) return "FAILED";
  const upper = s.toUpperCase();
  if (["SUCCESS", "SUCCESSFUL", "OK"].includes(upper)) return "SUCCESSFUL";
  if (["FAILED", "FAIL", "ERROR"].includes(upper)) return "FAILED";
  if (["SKIPPED", "IGNORE", "IGNORED"].includes(upper)) return "SKIPPED";
  return "FAILED";
}
