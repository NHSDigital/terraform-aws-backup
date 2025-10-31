import { S3Client, HeadObjectCommand, ListObjectsV2Command } from "@aws-sdk/client-s3";

const s3 = new S3Client({});

/* Example validator strategy:
   1. If event.expectedKeys provided -> verify each exists.
   2. Else if event.s3.bucket provided -> ensure bucket contains at least one object (or expectedMinObjects).
   Return status + message summarising findings.
*/

interface EventShape {
  restoreJobId: string;
  recoveryPointArn: string;
  resourceType: string;
  createdResourceArn?: string;
  targetBucket?: string;
  s3?: { bucket?: string };
  expectedKeys?: string[];
  expectedMinObjects?: number;
}

export const handler = async (event: EventShape) => {
  const bucket = event.targetBucket || event.s3?.bucket;
  if (!bucket) {
    return { status: "SKIPPED", message: "No bucket specified" };
  }

  if (event.expectedKeys && event.expectedKeys.length > 0) {
    const missing: string[] = [];
    for (const key of event.expectedKeys) {
      try {
        await s3.send(new HeadObjectCommand({ Bucket: bucket, Key: key }));
      } catch (e) {
        missing.push(key);
      }
    }
    if (missing.length > 0) {
      return { status: "FAILED", message: `Missing ${missing.length} objects`, missing };
    }
    return { status: "SUCCESSFUL", message: `All ${event.expectedKeys.length} expected objects present` };
  }

  // Fallback: simple non-empty check or min object threshold
  const min = event.expectedMinObjects ?? 1;
  let found = 0;
  let ContinuationToken: string | undefined = undefined;
  while (found < min) {
    const resp = await s3.send(new ListObjectsV2Command({ Bucket: bucket, MaxKeys: 1000, ContinuationToken }));
    const count = resp.Contents?.length || 0;
    found += count;
    if (!resp.IsTruncated) break;
    ContinuationToken = resp.NextContinuationToken;
  }
  if (found < min) {
    return { status: "FAILED", message: `Only ${found} objects found (< ${min})` };
  }
  return { status: "SUCCESSFUL", message: `Found ${found} objects (>= ${min})` };
};
