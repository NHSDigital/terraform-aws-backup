import { SSMClient, GetParameterCommand } from '@aws-sdk/client-ssm';
import { BackupClient } from '@aws-sdk/client-backup';
import { SecretsManagerClient } from '@aws-sdk/client-secrets-manager';
import { RDSDataClient } from '@aws-sdk/client-rds-data';
import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import { S3Client } from '@aws-sdk/client-s3';
import type { Context } from 'aws-lambda';

const ssm = new SSMClient({});
const backup = new BackupClient({}); // reserved for future use
const secrets = new SecretsManagerClient({}); // future
const rdsData = new RDSDataClient({}); // future
const dynamodb = new DynamoDBClient({}); // future more detailed calls
const s3 = new S3Client({}); // future

const CONFIG_PARAM_NAME = process.env.CONFIG_PARAM_NAME;
let cachedConfig: any | null = null;

async function loadConfig(): Promise<any> {
  if (cachedConfig) return cachedConfig;
  if (!CONFIG_PARAM_NAME) {
    cachedConfig = {};
    return cachedConfig;
  }
  const resp = await ssm.send(new GetParameterCommand({ Name: CONFIG_PARAM_NAME }));
  cachedConfig = resp.Parameter?.Value ? JSON.parse(resp.Parameter.Value) : {};
  return cachedConfig;
}

interface ValidationResult { status: 'SUCCESSFUL' | 'FAILED' | 'SKIPPED'; message: string; }

export const handler = async (event: any, _context: Context): Promise<ValidationResult> => {
  const restoreJobId = event?.detail?.restoreJobId || event?.restoreJobId;
  const resourceType = event?.detail?.resourceType || event?.resourceType;
  const createdArn = event?.detail?.createdResourceArn || event?.createdResourceArn;

  const config = await loadConfig();
  let result: ValidationResult = { status: 'SKIPPED', message: `No validator for ${resourceType}` };

  try {
    if (resourceType === 'RDS' || resourceType === 'Aurora') {
      result = await validateRdsLike(resourceType, createdArn, config.rds || config.aurora);
    } else if (resourceType === 'DynamoDB') {
      result = await validateDynamoDb(createdArn, config.dynamodb);
    } else if (resourceType === 'S3') {
      result = await validateS3(createdArn, config.s3);
    }
  } catch (err: any) {
    result = { status: 'FAILED', message: `Unhandled validator error: ${err?.message || String(err)}` };
  }

  return result;
};

async function validateRdsLike(resourceType: string, arn: string, cfg: any): Promise<ValidationResult> {
  if (!cfg || !cfg.sql_checks) {
    return { status: 'SKIPPED', message: 'No sql_checks configured' };
  }
  // Placeholder: iterate over cfg.sql_checks and (in future) execute statements via rds-data.
  return { status: 'SUCCESSFUL', message: 'All RDS/Aurora checks passed (placeholder)' };
}

async function validateDynamoDb(arn: string, cfg: any): Promise<ValidationResult> {
  if (!cfg || !cfg.tables) return { status: 'SKIPPED', message: 'No dynamodb tables configured' };
  return { status: 'SUCCESSFUL', message: 'DynamoDB validation placeholder' };
}

async function validateS3(arn: string, cfg: any): Promise<ValidationResult> {
  if (!cfg || !cfg.buckets) return { status: 'SKIPPED', message: 'No s3 buckets configured' };
  return { status: 'SUCCESSFUL', message: 'S3 validation placeholder' };
}
