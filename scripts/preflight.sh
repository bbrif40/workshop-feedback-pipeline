#!/usr/bin/env bash
set -euo pipefail

mkdir -p preflight

write_stop() {
  printf 'STOP: %s\n' "$1" > preflight/gate-status.txt
  printf 'STOP: %s\n' "$1"
  exit 2
}

if [[ "${AWS_REGION:-}" != "us-east-1" ]]; then
  write_stop "Open AWS CloudShell in us-east-1 and rerun the gate."
fi

aws configure list
aws --version
git --version
python3 --version

if ! python3 - <<'PY'
import sys
if sys.version_info < (3, 10):
    raise SystemExit("Python 3.10 or newer is required for boto3 1.44.3")
PY
then
  write_stop "CloudShell Python is older than 3.10."
fi

if ! aws sts get-caller-identity > preflight/identity.json; then
  write_stop "AWS caller identity could not be verified."
fi

if ! python3 - <<'PY'
import json
with open("preflight/identity.json", encoding="utf-8") as handle:
    identity = json.load(handle)
if identity["Arn"].endswith(":root"):
    raise SystemExit("Root credentials are not allowed")
PY
then
  write_stop "The active caller is the AWS account root user."
fi

if ! aws bedrock list-foundation-models > preflight/models.json 2> preflight/models-error.txt; then
  write_stop "Amazon Bedrock model listing failed. Review preflight/models-error.txt."
fi

if ! python3 - <<'PY'
import json
MODEL_ID = "amazon.nova-lite-v1:0"
with open("preflight/models.json", encoding="utf-8") as handle:
    models = json.load(handle).get("modelSummaries", [])
model_ids = {model.get("modelId") for model in models}
if MODEL_ID not in model_ids:
    raise SystemExit(f"Missing model ID: {MODEL_ID}")
PY
then
  write_stop "Amazon Nova Lite (amazon.nova-lite-v1:0) is not available in us-east-1."
fi

if ! aws bedrock-runtime converse \
  --model-id amazon.nova-lite-v1:0 \
  --messages '[{"role": "user", "content": [{"text": "Describe the purpose of a \"hello world\" program in one line."}]}]' \
  --inference-config '{"maxTokens": 512, "temperature": 0.5, "topP": 0.9}' \
  > preflight/nova-response.json 2> preflight/nova-error.txt
then
  write_stop "Amazon Nova Lite invocation failed. Review preflight/nova-error.txt."
fi

if ! aws comprehend detect-sentiment \
  --language-code en \
  --text "It is a beautiful day in Seattle" \
  > preflight/comprehend-response.json 2> preflight/comprehend-error.txt
then
  write_stop "Amazon Comprehend invocation failed. Review preflight/comprehend-error.txt and classify account-plan access before changing IAM."
fi

printf 'GO\n' > preflight/gate-status.txt
printf 'GO: Amazon Nova Lite and Amazon Comprehend are callable in us-east-1.\n'
