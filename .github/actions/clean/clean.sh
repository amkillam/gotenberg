#!/bin/bash

# Exit early.
# See: https://www.gnu.org/savannah-checkouts/gnu/bash/manual/bash.html#The-Set-Builtin.
set -e

# Source dot env file.
source .env

# Arguments.
tags=""
snapshot_version=""
dry_run=""

while [[ $# -gt 0 ]]; do
  case $1 in
  --tags)
    tags="$2"
    shift 2
    ;;
  --snapshot-version)
    snapshot_version="${2//v/}"
    shift 2
    ;;
  --dry-run)
    dry_run="$2"
    shift 2
    ;;
  *)
    echo "Unknown option $1"
    exit 1
    ;;
  esac
done

echo "Clean tag(s) from Docker Hub 🧹"
echo

tags_to_delete=()
for tag_to_delete in $(echo "$tags" | sed 's/,/ /g'); do
  tags_to_delete+=("${DOCKER_REGISTRY}/${DOCKER_REPOSITORY}${tag_to_delete}")
done

if [ -n "$snapshot_version" ]; then
  tags_to_delete+=("$DOCKER_REGISTRY/snapshot:$snapshot_version")
  tags_to_delete+=("$DOCKER_REGISTRY/snapshot:$snapshot_version-cloudrun")
fi

echo "Will delete the following tag(s):"
for tag in "${tags_to_delete[@]}"; do
  echo "- $tag"
done

if [ "$dry_run" = "true" ]; then
  echo "🚧 Dry run"
fi
echo

# Delete tags.
base_url="https://hub.docker.com/v2"
token=""

if [ "$dry_run" = "true" ]; then
  token="placeholder"
  echo "🚧 Dry run - would call $base_url to get a token"
  echo
else
  echo "🌐 Get token from $base_url"

  readarray -t lines < <(
    curl -s -X POST \
      -H "Content-Type: application/json" \
      -d "{\"username\":\"$DOCKERHUB_USERNAME\", \"password\":\"$DOCKERHUB_TOKEN\"}" \
      -w "\n%{http_code}" \
      "$base_url/users/login"
  )

  http_code="${lines[-1]}"
  unset 'lines[-1]'
  json_body=$(printf "%s\n" "${lines[@]}")

  if [ "$http_code" -ne "200" ]; then
    echo "❌ Wrong HTTP status - $http_code"
    echo "$json_body"
    exit 1
  fi

  token=$(jq -r '.token' <<<"$json_body")
  echo
fi

if [ -z "$token" ]; then
  echo "❌ No token from Docker Hub"
  exit 1
fi

for tag in "${tags_to_delete[@]}"; do
  if [ "$dry_run" = "true" ]; then
    echo "🚧 Dry run - would call $base_url to delete tag $tag"
    echo
  else
    echo "🌐 Delete tag $tag"
    IFS=':' read -ra tag_parts <<<"$tag"

    readarray -t lines < <(
      curl -s -X DELETE \
        -H "Authorization: Bearer $token" \
        -w "\n%{http_code}" \
        "$base_url/repositories/${tag_parts[0]}/tags/${tag_parts[1]}/"
    )

    http_code="${lines[-1]}"
    unset 'lines[-1]'

    if [ "$http_code" -ne "200" ] && [ "$http_code" -ne "204" ]; then
      echo "❌ Wrong HTTP status - $http_code"
      printf '%s\n' "${lines[@]}"
      exit 1
    fi

    echo
  fi
done

echo "✅ Done!"
exit 0
