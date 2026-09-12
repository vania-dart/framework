#!/usr/bin/env bash
#
# Regenerate Dart gRPC bindings for every *.proto file under ./proto.
#
# Prereqs (once per machine):
#   dart pub global activate protoc_plugin
#   brew install protobuf   # or your platform's protoc
#
# Then:
#   ./tool/generate_proto.sh

set -euo pipefail

cd "$(dirname "$0")/.."

OUT_DIR="lib/src/generated"
mkdir -p "$OUT_DIR"

PROTOC_GEN_DART="${PROTOC_GEN_DART:-$HOME/.pub-cache/bin/protoc-gen-dart}"
if [ ! -x "$PROTOC_GEN_DART" ]; then
  echo "protoc-gen-dart not found at $PROTOC_GEN_DART" >&2
  echo "Run: dart pub global activate protoc_plugin" >&2
  exit 1
fi

find proto -name '*.proto' -print0 | while IFS= read -r -d '' proto; do
  protoc \
    --plugin=protoc-gen-dart="$PROTOC_GEN_DART" \
    --dart_out=grpc:"$OUT_DIR" \
    -I proto \
    "$proto"
  echo "Generated: $proto"
done
