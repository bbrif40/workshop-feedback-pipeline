#!/usr/bin/env bash
set -euo pipefail

if [[ ! -f preflight/gate-status.txt ]] || [[ "$(cat preflight/gate-status.txt)" != "GO" ]]; then
  printf 'Deployment blocked. preflight/gate-status.txt must contain GO.\n'
  exit 2
fi

if [[ ! -f ingest.zip ]]; then
  printf 'Run bash scripts/build.sh before deployment.\n'
  exit 2
fi

FOUNDATION_STACK=workshop-feedback-foundation
APPLICATION_STACK=workshop-feedback-app

aws cloudformation deploy \
  --template-file infra/foundation.yaml \
  --stack-name "$FOUNDATION_STACK" \
  --no-fail-on-empty-changeset

BUCKET_NAME=$(aws cloudformation describe-stacks \
  --stack-name "$FOUNDATION_STACK" \
  --query "Stacks[0].Outputs[?OutputKey=='BucketName'].OutputValue" \
  --output text)

STATUS_TABLE=$(aws cloudformation describe-stacks \
  --stack-name "$FOUNDATION_STACK" \
  --query "Stacks[0].Outputs[?OutputKey=='StatusTableName'].OutputValue" \
  --output text)

STATUS_TABLE_ARN=$(aws cloudformation describe-stacks \
  --stack-name "$FOUNDATION_STACK" \
  --query "Stacks[0].Outputs[?OutputKey=='StatusTableArn'].OutputValue" \
  --output text)

aws s3 cp ingest.zip "s3://${BUCKET_NAME}/artifacts/ingest.zip"

aws cloudformation deploy \
  --template-file infra/application.yaml \
  --stack-name "$APPLICATION_STACK" \
  --capabilities CAPABILITY_IAM \
  --parameter-overrides \
    DataBucketName="$BUCKET_NAME" \
    StatusTableName="$STATUS_TABLE" \
    StatusTableArn="$STATUS_TABLE_ARN" \
    CodeKey=artifacts/ingest.zip \
  --no-fail-on-empty-changeset

printf 'export BUCKET_NAME=%q\n' "$BUCKET_NAME" > .runtime.env
printf 'export STATUS_TABLE=%q\n' "$STATUS_TABLE" >> .runtime.env
printf 'export FOUNDATION_STACK=%q\n' "$FOUNDATION_STACK" >> .runtime.env
printf 'export APPLICATION_STACK=%q\n' "$APPLICATION_STACK" >> .runtime.env

printf 'Deployment complete. Run: source .runtime.env\n'
