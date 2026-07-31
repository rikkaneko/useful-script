#!/usr/bin/env bash

# Exit immediately if a command exits with a non-zero status.
set -e;

# Initialize variables with us-east-1 as the default region.
DIR_PATH="";
ENDPOINT="";
ACCESS_KEY_ID="";
ACCESS_KEY_SECRET="";
BUCKET="";
REGION="us-east-1";
PRESET="";
CONFIG_FILE="";

# Temporary variables hold CLI arguments until config loading is complete.
ARG_PATH="";
ARG_ENDPOINT="";
ARG_ACCESS_KEY_ID="";
ARG_ACCESS_KEY_SECRET="";
ARG_BUCKET="";
ARG_REGION="";
ARG_PRESET="";

CONFIG_FILTER_ARGS=();
CLI_FILTER_ARGS=();
PRESET_FILTER_ARGS=();
FINAL_FILTER_ARGS=();

USAGE="Usage: $0 [--config <file>] [--path <dir>] [--endpoint <url>] [--access-key-id <id>] [--access-key-secret <secret>] [--bucket <bucket>] [--region <region>] [--preset <image|video>] [--include <pattern>] [--exclude <pattern>]";

# 1. Parse command line arguments.
while [[ "$#" -gt 0 ]]; do
  case $1 in
    --config)
      if [[ "$#" -lt 2 ]]; then
        echo "Error: --config requires a file path.";
        exit 1;
      fi;
      CONFIG_FILE="$2";
      shift;
      ;;
    --path)
      if [[ "$#" -lt 2 ]]; then
        echo "Error: --path requires a directory.";
        exit 1;
      fi;
      ARG_PATH="$2";
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
    --preset)
      if [[ "$#" -lt 2 ]]; then
        echo "Error: --preset requires 'image' or 'video'.";
        exit 1;
      fi;
      ARG_PRESET="$2";
      shift;
      ;;
    --include)
      if [[ "$#" -lt 2 ]]; then
        echo "Error: --include requires a pattern.";
        exit 1;
      fi;
      CLI_FILTER_ARGS+=(--include "$2");
      shift;
      ;;
    --exclude)
      if [[ "$#" -lt 2 ]]; then
        echo "Error: --exclude requires a pattern.";
        exit 1;
      fi;
      CLI_FILTER_ARGS+=(--exclude "$2");
      shift;
      ;;
    -h|--help)
      echo "$USAGE";
      echo "";
      echo "Presets:";
      echo "  image  Common image files: jpg, jpeg, png, webp, heic";
      echo "  video  Common video files: mp4, mov, m4v, avi, mkv, webm";
      echo "";
      echo "Filters use AWS CLI sync pattern syntax and may be repeated.";
      exit 0;
      ;;
    *)
      echo "Unknown parameter: $1";
      exit 1;
      ;;
  esac;
  shift;
done

# 2. Read from config file if provided.
if [[ -n "$CONFIG_FILE" ]]; then
  if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "Error: Config file '$CONFIG_FILE' not found.";
    exit 1;
  fi;

  # Read safely line by line to support spaces and avoid executing arbitrary code.
  while IFS='=' read -r key value || [ -n "$key" ]; do
    # Ignore comments and empty lines.
    [[ "$key" =~ ^#.*$ ]] || [[ -z "$key" ]] && continue;

    # Trim leading and trailing whitespace.
    key="${key#"${key%%[![:space:]]*}"}"; key="${key%"${key##*[![:space:]]}"}";
    value="${value#"${value%%[![:space:]]*}"}"; value="${value%"${value##*[![:space:]]}"}";

    # Remove surrounding quotes from the value if they exist.
    value="${value#\"}"; value="${value%\"}";
    value="${value#\'}"; value="${value%\'}";

    case "$key" in
      path) DIR_PATH="$value" ;;
      endpoint) ENDPOINT="$value" ;;
      access-key-id) ACCESS_KEY_ID="$value" ;;
      access-key-secret) ACCESS_KEY_SECRET="$value" ;;
      bucket) BUCKET="$value" ;;
      region) REGION="$value" ;;
      preset) PRESET="$value" ;;
      include) CONFIG_FILTER_ARGS+=(--include "$value") ;;
      exclude) CONFIG_FILTER_ARGS+=(--exclude "$value") ;;
    esac;
  done < "$CONFIG_FILE";
fi

# 3. Apply CLI overrides. CLI scalar arguments always take precedence over the config file.
[[ -n "$ARG_PATH" ]] && DIR_PATH="$ARG_PATH";
[[ -n "$ARG_ENDPOINT" ]] && ENDPOINT="$ARG_ENDPOINT";
[[ -n "$ARG_ACCESS_KEY_ID" ]] && ACCESS_KEY_ID="$ARG_ACCESS_KEY_ID";
[[ -n "$ARG_ACCESS_KEY_SECRET" ]] && ACCESS_KEY_SECRET="$ARG_ACCESS_KEY_SECRET";
[[ -n "$ARG_BUCKET" ]] && BUCKET="$ARG_BUCKET";
[[ -n "$ARG_REGION" ]] && REGION="$ARG_REGION";
[[ -n "$ARG_PRESET" ]] && PRESET="$ARG_PRESET";

# 4. Validate that all required arguments are populated.
if [[ -z "$DIR_PATH" || -z "$ENDPOINT" || -z "$ACCESS_KEY_ID" || -z "$ACCESS_KEY_SECRET" || -z "$BUCKET" ]]; then
  echo "Error: Missing required parameters.";
  echo "Please provide them via CLI arguments or a --config file.";
  echo "$USAGE";
  exit 1;
fi

case "$PRESET" in
  "")
    ;;
  image)
    PRESET_FILTER_ARGS=(
      --exclude "*"
      --include "*.jpg"
      --include "*.jpeg"
      --include "*.png"
      --include "*.webp"
      --include "*.heic"
      --include "*.JPG"
      --include "*.JPEG"
      --include "*.PNG"
      --include "*.WEBP"
      --include "*.HEIC"
    );
    ;;
  video)
    PRESET_FILTER_ARGS=(
      --exclude "*"
      --include "*.mp4"
      --include "*.mov"
      --include "*.m4v"
      --include "*.avi"
      --include "*.mkv"
      --include "*.webm"
      --include "*.MP4"
      --include "*.MOV"
      --include "*.M4V"
      --include "*.AVI"
      --include "*.MKV"
      --include "*.WEBM"
    );
    ;;
  *)
    echo "Error: Unsupported preset '$PRESET'. Expected 'image' or 'video'.";
    exit 1;
    ;;
esac;

FINAL_FILTER_ARGS=("${PRESET_FILTER_ARGS[@]}" "${CONFIG_FILTER_ARGS[@]}" "${CLI_FILTER_ARGS[@]}");

# Verify the directory exists.
if [[ ! -d "$DIR_PATH" ]]; then
  echo "Error: Directory '$DIR_PATH' does not exist.";
  exit 1;
fi

# Verify aws-cli is installed.
if ! command -v aws &> /dev/null; then
  echo "Error: 'aws' CLI is not installed. Install via: pkg install aws-cli";
  exit 1;
fi

# Export credentials and region as environment variables for aws-cli.
export AWS_ACCESS_KEY_ID="$ACCESS_KEY_ID";
export AWS_SECRET_ACCESS_KEY="$ACCESS_KEY_SECRET";
export AWS_DEFAULT_REGION="$REGION";

echo "Starting S3 sync from '$DIR_PATH' to bucket '$BUCKET' (Region: $REGION)...";
if [[ -n "$PRESET" ]]; then
  echo "Using '$PRESET' preset filters.";
fi;
if [[ "${#CONFIG_FILTER_ARGS[@]}" -gt 0 || "${#CLI_FILTER_ARGS[@]}" -gt 0 ]]; then
  echo "Using custom include/exclude filters.";
fi;
if [[ "${#FINAL_FILTER_ARGS[@]}" -eq 0 ]]; then
  echo "No filters configured; all files are eligible for sync.";
fi;
echo "Files that already exist in the bucket will be skipped automatically.";

# Execute the sync.
aws s3 sync "$DIR_PATH" "s3://$BUCKET/" \
  --endpoint-url "$ENDPOINT" \
  "${FINAL_FILTER_ARGS[@]}";

echo "Upload complete!";
