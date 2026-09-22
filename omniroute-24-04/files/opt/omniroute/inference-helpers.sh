#!/bin/bash
# OmniRoute-only helpers on top of the shared
# /var/lib/digitalocean/inference-models.sh helpers.
# Do not put OmniRoute-specific filters in common/.

# Extra non-chat filters beyond the shared helper (e.g. sentence-transformers).
omniroute_filter_chat_models() {
  local id
  while IFS= read -r id; do
    [ -n "$id" ] || continue
    case "$id" in
      *mini-lm*|*all-mini*|*bge-*|*e5-*) continue ;;
    esac
    printf '%s\n' "$id"
  done
}

# Prefer Marketplace-friendly chat defaults when present in the live list.
omniroute_pick_default_model() {
  local id preferred
  local -a models=()
  local preferred_ids="minimax-m2.5 kimi-k3 kimi-k2.5 openai-gpt-5.5 openai-gpt-5.2"

  while IFS= read -r id; do
    [ -n "$id" ] || continue
    models+=("$id")
  done

  if [ "${#models[@]}" -eq 0 ]; then
    return 1
  fi

  for preferred in $preferred_ids; do
    for id in "${models[@]}"; do
      if [ "$id" = "$preferred" ]; then
        printf '%s' "$id"
        return 0
      fi
    done
  done

  printf '%s' "${models[0]}"
  return 0
}

# Full pipeline: shared chat filter + OmniRoute extras.
omniroute_list_chat_models_from_json() {
  printf '%s' "$1" | parse_inference_model_ids | filter_chat_inference_models | omniroute_filter_chat_models
}
