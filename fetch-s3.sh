#!/usr/bin/env bash

# Exit immediately if a command exits with a non-zero status.
set -e;
set -o pipefail;

COMMAND="";
CONFIG_FILE="";
ENDPOINT="";
ACCESS_KEY_ID="";
ACCESS_KEY_SECRET="";
BUCKET="";
REGION="us-east-1";
PREFIX="";
DESTINATION="";
KEY="";
FORMAT="table";
EXPIRES_IN="3600";
MAX_ITEMS="50";
OBJECT_TAG="false";

ARG_ENDPOINT="";
ARG_ACCESS_KEY_ID="";
ARG_ACCESS_KEY_SECRET="";
ARG_BUCKET="";
ARG_REGION="";

USAGE="Usage: $0 <list|download|url> [--config <file>] [--endpoint <url>] [--access-key-id <id>] [--access-key-secret <secret>] [--bucket <bucket>] [--region <region>] [--prefix <prefix>] [--destination <dir>] [--key <object-key>] [--format <table|json>] [--expires-in <seconds>] [--max-items <N>] [--object-tag]";

# Parse one explicit subcommand plus common and mode-specific options.
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    list|download|url)
      if [[ -n "$COMMAND" ]]; then
        echo "Error: Multiple subcommands provided.";
        exit 1;
      fi;
      COMMAND="$1";
      ;;
    --config)
      if [[ "$#" -lt 2 ]]; then
        echo "Error: --config requires a file path.";
        exit 1;
      fi;
      CONFIG_FILE="$2";
      shift;
      ;;
    --endpoint)
      if [[ "$#" -lt 2 ]]; then
        echo "Error: --endpoint requires a URL.";
        exit 1;
      fi;
      ARG_ENDPOINT="$2";
      shift;
      ;;
    --access-key-id)
      if [[ "$#" -lt 2 ]]; then
        echo "Error: --access-key-id requires a value.";
        exit 1;
      fi;
      ARG_ACCESS_KEY_ID="$2";
      shift;
      ;;
    --access-key-secret)
      if [[ "$#" -lt 2 ]]; then
        echo "Error: --access-key-secret requires a value.";
        exit 1;
      fi;
      ARG_ACCESS_KEY_SECRET="$2";
      shift;
      ;;
    --bucket)
      if [[ "$#" -lt 2 ]]; then
        echo "Error: --bucket requires a bucket name.";
        exit 1;
      fi;
      ARG_BUCKET="$2";
      shift;
      ;;
    --region)
      if [[ "$#" -lt 2 ]]; then
        echo "Error: --region requires a value.";
        exit 1;
      fi;
      ARG_REGION="$2";
      shift;
      ;;
    --prefix)
      if [[ "$#" -lt 2 ]]; then
        echo "Error: --prefix requires a value.";
        exit 1;
      fi;
      PREFIX="$2";
      shift;
      ;;
    --destination)
      if [[ "$#" -lt 2 ]]; then
        echo "Error: --destination requires a directory.";
        exit 1;
      fi;
      DESTINATION="$2";
      shift;
      ;;
    --key)
      if [[ "$#" -lt 2 ]]; then
        echo "Error: --key requires a full object key.";
        exit 1;
      fi;
      KEY="$2";
      shift;
      ;;
    --format)
      if [[ "$#" -lt 2 ]]; then
        echo "Error: --format requires 'table' or 'json'.";
        exit 1;
      fi;
      FORMAT="$2";
      shift;
      ;;
    --expires-in)
      if [[ "$#" -lt 2 ]]; then
        echo "Error: --expires-in requires a number of seconds.";
        exit 1;
      fi;
      EXPIRES_IN="$2";
      shift;
      ;;
    --max-items)
      if [[ "$#" -lt 2 ]]; then
        echo "Error: --max-items requires a positive integer.";
        exit 1;
      fi;
      MAX_ITEMS="$2";
      shift;
      ;;
    --object-tag)
      OBJECT_TAG="true";
      ;;
    -h|--help)
      echo "$USAGE";
      echo "";
      echo "Commands:";
      echo "  list      List object name and size, optionally filtered by prefix.";
      echo "  download  Download all objects under a prefix to a destination directory.";
      echo "  url       Generate a presigned URL for a full object key.";
      exit 0;
      ;;
    *)
      if [[ "$1" == --* || -n "$COMMAND" ]]; then
        echo "Unknown parameter: $1";
      else
        echo "Unknown subcommand: $1";
      fi;
      exit 1;
      ;;
  esac;
  shift;
done

# Read the shared S3 endpoint configuration format.
if [[ -n "$CONFIG_FILE" ]]; then
  if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "Error: Config file '$CONFIG_FILE' not found.";
    exit 1;
  fi;

  while IFS='=' read -r config_key config_value || [ -n "$config_key" ]; do
    [[ "$config_key" =~ ^#.*$ ]] || [[ -z "$config_key" ]] && continue;

    config_key="${config_key#"${config_key%%[![:space:]]*}"}"; config_key="${config_key%"${config_key##*[![:space:]]}"}";
    config_value="${config_value#"${config_value%%[![:space:]]*}"}"; config_value="${config_value%"${config_value##*[![:space:]]}"}";
    config_value="${config_value#\"}"; config_value="${config_value%\"}";
    config_value="${config_value#\'}"; config_value="${config_value%\'}";

    case "$config_key" in
      endpoint) ENDPOINT="$config_value" ;;
      access-key-id) ACCESS_KEY_ID="$config_value" ;;
      access-key-secret) ACCESS_KEY_SECRET="$config_value" ;;
      bucket) BUCKET="$config_value" ;;
      region) REGION="$config_value" ;;
    esac;
  done < "$CONFIG_FILE";
fi

# CLI endpoint options override config values.
[[ -n "$ARG_ENDPOINT" ]] && ENDPOINT="$ARG_ENDPOINT";
[[ -n "$ARG_ACCESS_KEY_ID" ]] && ACCESS_KEY_ID="$ARG_ACCESS_KEY_ID";
[[ -n "$ARG_ACCESS_KEY_SECRET" ]] && ACCESS_KEY_SECRET="$ARG_ACCESS_KEY_SECRET";
[[ -n "$ARG_BUCKET" ]] && BUCKET="$ARG_BUCKET";
[[ -n "$ARG_REGION" ]] && REGION="$ARG_REGION";

if [[ -z "$COMMAND" ]]; then
  echo "Error: Missing subcommand.";
  echo "$USAGE";
  exit 1;
fi;

if [[ -z "$ENDPOINT" || -z "$ACCESS_KEY_ID" || -z "$ACCESS_KEY_SECRET" || -z "$BUCKET" ]]; then
  echo "Error: Missing required S3 endpoint parameters.";
  echo "Please provide them via CLI arguments or a --config file.";
  echo "$USAGE";
  exit 1;
fi;

if ! command -v aws &> /dev/null; then
  echo "Error: 'aws' CLI is not installed. Install via: pkg install aws-cli";
  exit 1;
fi;

if ! command -v python3 &> /dev/null; then
  echo "Error: 'python3' is required to format list output.";
  exit 1;
fi;

export AWS_ACCESS_KEY_ID="$ACCESS_KEY_ID";
export AWS_SECRET_ACCESS_KEY="$ACCESS_KEY_SECRET";
export AWS_DEFAULT_REGION="$REGION";

case "$COMMAND" in
  list)
    if [[ "$FORMAT" != "table" && "$FORMAT" != "json" ]]; then
      echo "Error: --format must be 'table' or 'json'.";
      exit 1;
    fi;
    if [[ ! "$MAX_ITEMS" =~ ^[0-9]+$ || "$MAX_ITEMS" -eq 0 ]]; then
      echo "Error: --max-items must be a positive integer.";
      exit 1;
    fi;

    aws s3api list-objects-v2 \
      --bucket "$BUCKET" \
      --prefix "$PREFIX" \
      --endpoint-url "$ENDPOINT" \
      --max-items "$MAX_ITEMS" \
      --output json | S3_ENDPOINT="$ENDPOINT" S3_BUCKET="$BUCKET" S3_FORMAT="$FORMAT" S3_OBJECT_TAG="$OBJECT_TAG" python3 -c '
import json
import os
import subprocess
import sys

payload = json.loads(sys.stdin.read() or "{}")
objects = payload.get("Contents") or []
rows = []
include_tags = os.environ["S3_OBJECT_TAG"] == "true"

for item in objects:
  key = str(item.get("Key", ""))
  size = item.get("Size", 0)
  row = {"name": key, "size": size}
  if include_tags:
    tags = {}
    completed = subprocess.run(
      [
        "aws",
        "s3api",
        "get-object-tagging",
        "--bucket",
        os.environ["S3_BUCKET"],
        "--key",
        key,
        "--endpoint-url",
        os.environ["S3_ENDPOINT"],
        "--output",
        "json",
      ],
      check=False,
      capture_output=True,
      text=True,
    )
    if completed.returncode == 0:
      tags_payload = json.loads(completed.stdout or "{}")
      for tag in tags_payload.get("TagSet") or []:
        tags[str(tag.get("Key", ""))] = str(tag.get("Value", ""))
    row["tags"] = tags
  rows.append(row)

if os.environ["S3_FORMAT"] == "json":
  print(json.dumps(rows, indent=2, ensure_ascii=False))
else:
  rendered_rows = []
  for row in rows:
    rendered_row = [row["name"], str(row["size"])]
    if include_tags:
      tag_text = ", ".join([f"{name}={value}" for name, value in row["tags"].items()]) or "-"
      rendered_row.append(tag_text)
    rendered_rows.append(rendered_row)
  widths = [4, 4]
  if include_tags:
    widths.append(4)
  for rendered_row in rendered_rows:
    widths[0] = max(widths[0], len(rendered_row[0]))
    widths[1] = max(widths[1], len(rendered_row[1]))
    if include_tags:
      widths[2] = max(widths[2], len(rendered_row[2]))
  header_name = "NAME"
  header_size = "SIZE"
  if include_tags:
    header_tags = "TAGS"
    print(f"{header_name:<{widths[0]}}  {header_size:>{widths[1]}}  {header_tags:<{widths[2]}}")
  else:
    print(f"{header_name:<{widths[0]}}  {header_size:>{widths[1]}}")
  for rendered_row in rendered_rows:
    if include_tags:
      print(f"{rendered_row[0]:<{widths[0]}}  {rendered_row[1]:>{widths[1]}}  {rendered_row[2]:<{widths[2]}}")
    else:
      print(f"{rendered_row[0]:<{widths[0]}}  {rendered_row[1]:>{widths[1]}}")
';
    ;;
  download)
    if [[ -z "$PREFIX" ]]; then
      echo "Error: download requires --prefix.";
      exit 1;
    fi;
    if [[ -z "$DESTINATION" ]]; then
      echo "Error: download requires --destination.";
      exit 1;
    fi;

    mkdir -p "$DESTINATION";
    aws s3 sync "s3://$BUCKET/$PREFIX" "$DESTINATION" \
      --endpoint-url "$ENDPOINT";
    ;;
  url)
    if [[ -z "$KEY" ]]; then
      echo "Error: url requires --key.";
      exit 1;
    fi;
    if [[ ! "$EXPIRES_IN" =~ ^[0-9]+$ || "$EXPIRES_IN" -eq 0 ]]; then
      echo "Error: --expires-in must be a positive integer.";
      exit 1;
    fi;

    aws s3 presign "s3://$BUCKET/$KEY" \
      --endpoint-url "$ENDPOINT" \
      --expires-in "$EXPIRES_IN";
    ;;
esac;
