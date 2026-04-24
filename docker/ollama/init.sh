#!/bin/sh
# Pull default cleanup models on first Ollama boot. Idempotent — Ollama skips already-present models.

set -e

MODELS="${TALKTYPE_MODELS:-qwen2.5:3b llama3.2:3b}"

echo "[talktype] ensuring Ollama models are present: $MODELS"

# Wait for the server to answer
for i in 1 2 3 4 5 6 7 8 9 10; do
  if ollama list >/dev/null 2>&1; then
    break
  fi
  sleep 2
done

for model in $MODELS; do
  if ollama list | awk '{print $1}' | grep -q "^${model}$"; then
    echo "[talktype] $model already present — skipping pull"
  else
    echo "[talktype] pulling $model"
    ollama pull "$model"
  fi
done

echo "[talktype] model init complete"
