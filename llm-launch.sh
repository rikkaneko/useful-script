#!/bin/bash
if [[ "${1}" == "--help" ]]; then
  echo "${0} <model-dir> [--alias <name> --context-size <N> --max-user <N> --use-mtp --nothink --embeddings --multimodel --use-ssl]";
  exit 0
elif [[ "${1}" != "" ]]; then
  MODEL_DIR=${1};
  shift
else
  echo "Please specify the model dir"
  exit 1
fi

MODEL_ALIAS="default"
CONTEXT_SIZE="327680"
MAX_USER="25"
PORT=8080
USE_MTP=0
NOTHINK=0
USE_EMBEDDING=0
USE_MULTIMODEL=0
USE_SSL=0
EXTRA_ARGS=""

# Loop through all arguments passed to the script
while [[ $# -gt 0 ]]; do
  case "$1" in
    --alias)
      MODEL_ALIAS="$2"
      shift 2
      ;;
    --alias=*)
      MODEL_ALIAS="${1#*=}"
      shift 1
      ;;
    --context-size)
      CONTEXT_SIZE="$2"
      shift 2
      ;;
    --context-size=*)
      CONTEXT_SIZE="${1#*=}"
      shift 1
      ;;
    --max-user)
      MAX_USER="$2"
      shift 2
      ;;
    --max-user=*)
      MAX_USER="${1#*=}"
      shift 1
      ;;
    --use-mtp)
      USE_MTP=1
      shift 1
      ;;
    --nothink)
      NOTHINK=1
      shift 1
      ;;
    --embeddings)
      USE_EMBEDDING=1
      shift 1
      ;;
    --multimodel)
      USE_MULTIMODEL=1
      shift 1
      ;;
    --use-ssl)
      USE_SSL=1
      shift 1
      ;;
    *)
      EXTRA_ARGS+="$1 "
      shift 1
      ;;
  esac
done

if [[ "$CONTEXT_SIZE" =~ ^[0-9]+$ ]] && [[ "$MAX_USER" =~ ^[0-9]+$ ]]; then
  CONTEXT_SIZE=$(( CONTEXT_SIZE * MAX_USER ))
else
  echo "Warning: Could not calculate final CONTEXT_SIZE. Ensure both --context and --max-user are valid integers."
fi

if [[ "${USE_MTP}" -eq 1 ]]; then
  USE_MTP="--spec-type draft-mtp --spec-draft-n-max 2"
else
  USE_MTP=""
fi

if [[ "${USE_EMBEDDING}" -eq -1 ]]; then
  USE_EMBEDDING="--embeddings --pooling mean"
else
  USE_EMBEDDING=""
fi

if [[ "${NOTHINK}" -eq 1 ]]; then
  NOTHINK="--reasoning off"
else
  NOTHINK=""
fi

if [[ "$USE_MULTIMODEL" -eq 1 ]]; then
  
  TARGET_DIR="${MODEL_DIR%/*}"
  if [ "$TARGET_DIR" = "$MODEL_DIR" ]; then
    TARGET_DIR="."
  fi

  # Find the first matching file without using mapfile
  while IFS= read -r file; do
    if [ -n "$file" ]; then
      SELECTED_MMPROJ="$file"
      break # Exit the loop as soon as we find the first match
    fi
  done < <(find "$TARGET_DIR" -maxdepth 1 -type f -name "*mmproj-*.gguf" 2>/dev/null)
   
  if [ -z "$SELECTED_MMPROJ" ]; then
    echo "Error: No mmproj-*.gguf files found under '$TARGET_DIR'." >&2
    USE_MULTIMODEL=""  # Fallback to empty so the rest of your startup script won't crash
  else
    echo "Using multimodel file: $SELECTED_MMPROJ"
    USE_MULTIMODEL="--mmproj ${SELECTED_MMPROJ}"
  fi
    
else
  USE_MULTIMODEL=""
fi

if [[ "USE_SSL" -eq 1 ]]; then
  USE_SSL="--ssl-cert-file ~/certs/fullchain.pem --ssl-key-file ~/certs/privkey.pem"
else
  USE_SSL=""
fi

echo "========================"
echo "Model Directory:          ${MODEL_DIR}" 
echo "Alias Name:               ${MODEL_ALIAS}"
echo "Maximum Concurrent User:  ${MAX_USER}"
echo "Total Context Size:       ${CONTEXT_SIZE}"
echo "Extra Arguments:          $USE_MTP $USE_EMBEDDING $NOTHINK $USE_MULTIMODEL $EXTRA_ARGS"
echo "========================"

sleep 3

llama-server \
  --verbose \
  --metrics \
  --model ${MODEL_DIR} \
  --alias "${MODEL_ALIAS}" \
  --api-key-file "${HOME}"/.llm_api_key \
  --kv-unified \
  --ctx-size ${CONTEXT_SIZE} \
  --parallel ${MAX_USER} \
  --cont-batching \
  --flash-attn on \
  --n-gpu-layers 99 \
  --batch-size 4096 \
  --ubatch-size 4096 \
  --cache-reuse 128 \
  -t 24 -tb 24 --cpu-mask 0xFFFFFF \
  $USE_MTP $USE_EMBEDDING $NOTHINK $USE_MULTIMODEL $USE_SSL $EXTRA_ARGS