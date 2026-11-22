#!/usr/bin/env bash
# Regenerate the Go and Dart code for the dlss.v1 contract.
#
# Pinned toolchain (must match .fvmrc, backend/go.mod/frontend/pubspec.yaml,
# and .github/workflows/new-stack.yml):
#   protoc               36.1
#   protoc-gen-go        1.36.12
#   protoc-gen-go-grpc   1.6.2
#   protoc_plugin        25.1.0
#
# Both output trees are entirely generated, so they are wiped first; a run
# leaves exactly the files that belong to the current proto set.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROTO_ROOT="$ROOT/proto"
GO_OUT="$ROOT/backend/gen"
DART_OUT="$ROOT/frontend/lib/src/generated"
PROTOC="${PROTOC:-protoc}"

EXPECTED_PROTOC="libprotoc 36.1"
EXPECTED_GO_PLUGIN="protoc-gen-go v1.36.12"
EXPECTED_GO_GRPC_PLUGIN="protoc-gen-go-grpc 1.6.2"

die() {
  printf 'codegen: %s\n' "$*" >&2
  exit 1
}

command -v "$PROTOC" >/dev/null 2>&1 || die "protoc not found; install protoc 36.1"

actual_protoc="$("$PROTOC" --version)"
[[ "$actual_protoc" == "$EXPECTED_PROTOC" ]] ||
  die "protoc $EXPECTED_PROTOC required, found '$actual_protoc'"

gopath="$(go env GOPATH)"
GO_PLUGIN="${PROTOC_GEN_GO:-$gopath/bin/protoc-gen-go}"
GO_GRPC_PLUGIN="${PROTOC_GEN_GO_GRPC:-$gopath/bin/protoc-gen-go-grpc}"
DART_PLUGIN="${PROTOC_GEN_DART:-$HOME/.pub-cache/bin/protoc-gen-dart}"

for plugin in "$GO_PLUGIN" "$GO_GRPC_PLUGIN" "$DART_PLUGIN"; do
  [[ -x "$plugin" ]] || die "missing plugin $plugin"
done

actual_go="$("$GO_PLUGIN" --version)"
[[ "$actual_go" == "$EXPECTED_GO_PLUGIN" ]] ||
  die "$EXPECTED_GO_PLUGIN required, found '$actual_go'"

actual_go_grpc="$("$GO_GRPC_PLUGIN" --version)"
[[ "$actual_go_grpc" == "$EXPECTED_GO_GRPC_PLUGIN" ]] ||
  die "$EXPECTED_GO_GRPC_PLUGIN required, found '$actual_go_grpc'"

mapfile -t proto_files < <(find "$PROTO_ROOT" -type f -name '*.proto' | LC_ALL=C sort)
[[ ${#proto_files[@]} -gt 0 ]] || die "no .proto files under $PROTO_ROOT"

relative_protos=()
for file in "${proto_files[@]}"; do
  relative_protos+=("${file#"$PROTO_ROOT"/}")
done

rm -rf "$GO_OUT/dlss" "$DART_OUT/dlss"
mkdir -p "$GO_OUT" "$DART_OUT"

"$PROTOC" \
  -I "$PROTO_ROOT" \
  --plugin="protoc-gen-go=$GO_PLUGIN" \
  --plugin="protoc-gen-go-grpc=$GO_GRPC_PLUGIN" \
  --plugin="protoc-gen-dart=$DART_PLUGIN" \
  --go_out="$GO_OUT" \
  --go_opt=paths=source_relative \
  --go-grpc_out="$GO_OUT" \
  --go-grpc_opt=paths=source_relative \
  --dart_out=grpc:"$DART_OUT" \
  "${relative_protos[@]}"

printf 'codegen: protoc %s, %s, %s, protoc_plugin 25.1.0\n' \
  "${actual_protoc#libprotoc }" "${actual_go#protoc-gen-go }" "${actual_go_grpc#protoc-gen-go-grpc }"
