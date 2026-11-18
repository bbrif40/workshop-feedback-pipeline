#!/usr/bin/env bash
set -euo pipefail

rm -rf package ingest.zip
python3 -m pip install --target package --requirement requirements.txt
cp src/handler.py package/handler.py
(
  cd package
  zip -r ../ingest.zip .
)

STATUS_TABLE=test-status-table PYTHONPATH=package \
  python3 -m unittest discover -s tests -v
