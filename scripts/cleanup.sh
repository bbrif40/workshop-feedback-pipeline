#!/usr/bin/env bash
set -euo pipefail

if [[ ! -f .runtime.env ]]; then
  printf '.runtime.env is missing. Retrieve the stack outputs before cleanup.\n'
  exit 2
fi

source .runtime.env

aws cloudformation delete-stack --stack-name "$APPLICATION_STACK"
aws cloudformation wait stack-delete-complete --stack-name "$APPLICATION_STACK"

aws s3 rm "s3://${BUCKET_NAME}" --recursive
aws s3 ls "s3://${BUCKET_NAME}"

aws cloudformation delete-stack --stack-name "$FOUNDATION_STACK"
aws cloudformation wait stack-delete-complete --stack-name "$FOUNDATION_STACK"

rm -rf package ingest.zip .runtime.env
printf 'AWS project resources deleted. Delete the GitHub token in GitHub settings.\n'
