#!/usr/bin/env bash
set -euo pipefail

readonly PROGRAM_NAME="proof-validator.sh"
readonly REPORT_SCHEMA_VERSION="1.0"
readonly SHA256_HEX_PATTERN='^[0-9a-f]{64}$'

usage() {
  cat <<'USAGE'
Usage:
  tools/proof-validator.sh [--root DIRECTORY] [--output REPORT.json] [ALN_PATH ...]

Checks ARTIFACT/SHA256 pairs declared in ALN files.

Supported declaration format:
  ARTIFACT path/to/referenced-artifact
  SHA256 0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef

Options:
  --root DIRECTORY   Repository root. Defaults to the current directory.
  --output FILE      Write JSON report to FILE. Defaults to standard output.
  --help             Show this help text.

If no ALN_PATH values are given, the tool recursively scans the repository root
for files ending in .aln, excluding .git.
USAGE
}

json_escape() {
  local value=$1
  value=${value//\\/\\\\}
  value=${value//\"/\\\"}
  value=${value//$'\n'/\\n}
  value=${value//$'\r'/\\r}
  value=${value//$'\t'/\\t}
  printf '%s' "$value"
}

canonical_path() {
  local candidate=$1

  if command -v realpath >/dev/null 2>&1; then
    realpath -e -- "$candidate"
  else
    (
      cd -- "$(dirname -- "$candidate")"
      printf '%s/%s\n' "$PWD" "$(basename -- "$candidate")"
    )
  fi
}

path_is_within_root() {
  local root=$1
  local target=$2

  [[ "$target" == "$root" || "$target" == "$root/"* ]]
}

require_command() {
  local command_name=$1

  if ! command -v "$command_name" >/dev/null 2>&1; then
    printf '%s\n' "$PROGRAM_NAME: required command not found: $command_name" >&2
    exit 69
  fi
}

root_dir=$PWD
output_file=""
declare -a requested_paths=()

while (($# > 0)); do
  case "$1" in
    --root)
      (($# >= 2)) || {
        printf '%s\n' "$PROGRAM_NAME: --root requires a directory." >&2
        exit 64
      }
      root_dir=$2
      shift 2
      ;;
    --output)
      (($# >= 2)) || {
        printf '%s\n' "$PROGRAM_NAME: --output requires a path." >&2
        exit 64
      }
      output_file=$2
      shift 2
      ;;
    --help)
      usage
      exit 0
      ;;
    --)
      shift
      requested_paths+=("$@")
      break
      ;;
    -*)
      printf '%s\n' "$PROGRAM_NAME: unknown option: $1" >&2
      usage >&2
      exit 64
      ;;
    *)
      requested_paths+=("$1")
      shift
      ;;
  esac
done

require_command awk
require_command find
require_command sha256sum
require_command sort

if [[ ! -d "$root_dir" ]]; then
  printf '%s\n' "$PROGRAM_NAME: repository root is not a directory: $root_dir" >&2
  exit 66
fi

repo_root=$(canonical_path "$root_dir")

declare -a aln_files=()
if ((${#requested_paths[@]} == 0)); then
  while IFS= read -r -d '' path; do
    aln_files+=("$path")
  done < <(find "$repo_root" -type d -name .git -prune -o -type f -name '*.aln' -print0 | sort -z)
else
  for requested_path in "${requested_paths[@]}"; do
    candidate=$requested_path
    if [[ "$candidate" != /* ]]; then
      candidate="$repo_root/$candidate"
    fi

    if [[ ! -f "$candidate" ]]; then
      printf '%s\n' "$PROGRAM_NAME: ALN file does not exist: $requested_path" >&2
      exit 66
    fi

    canonical_candidate=$(canonical_path "$candidate")
    if ! path_is_within_root "$repo_root" "$canonical_candidate"; then
      printf '%s\n' "$PROGRAM_NAME: ALN path escapes repository root: $requested_path" >&2
      exit 65
    fi

    aln_files+=("$canonical_candidate")
  done
fi

declare -a results=()
checked_count=0
passed_count=0
failed_count=0

record_result() {
  local aln_path=$1
  local line_number=$2
  local artifact_path=$3
  local declared_sha256=$4
  local actual_sha256=$5
  local status=$6
  local reason=$7

  local relative_aln=${aln_path#"$repo_root"/}
  local relative_artifact=$artifact_path
  if [[ "$artifact_path" == "$repo_root/"* ]]; then
    relative_artifact=${artifact_path#"$repo_root"/}
  fi

  results+=(
    "{\"aln_file\":\"$(json_escape "$relative_aln")\",\"line\":$line_number,\"artifact\":\"$(json_escape "$relative_artifact")\",\"declared_sha256\":\"$(json_escape "$declared_sha256")\",\"actual_sha256\":\"$(json_escape "$actual_sha256")\",\"status\":\"$(json_escape "$status")\",\"reason\":\"$(json_escape "$reason")\"}"
  )

  checked_count=$((checked_count + 1))
  if [[ "$status" == "passed" ]]; then
    passed_count=$((passed_count + 1))
  else
    failed_count=$((failed_count + 1))
  fi
}

for aln_path in "${aln_files[@]}"; do
  pending_artifact=""
  pending_line=0

  while IFS=$'\t' read -r line_number kind value; do
    case "$kind" in
      artifact)
        if [[ -n "$pending_artifact" ]]; then
          record_result \
            "$aln_path" \
            "$pending_line" \
            "$pending_artifact" \
            "" \
            "" \
            "failed" \
            "missing SHA256 declaration before next ARTIFACT or END"
        fi
        pending_artifact=$value
        pending_line=$line_number
        ;;
      sha256)
        if [[ -z "$pending_artifact" ]]; then
          record_result \
            "$aln_path" \
            "$line_number" \
            "" \
            "$value" \
            "" \
            "failed" \
            "SHA256 declaration has no preceding ARTIFACT declaration"
          continue
        fi

        declared_sha256=${value,,}
        if ! [[ "$declared_sha256" =~ $SHA256_HEX_PATTERN ]]; then
          record_result \
            "$aln_path" \
            "$pending_line" \
            "$pending_artifact" \
            "$declared_sha256" \
            "" \
            "failed" \
            "SHA256 value must be exactly 64 lowercase hexadecimal characters"
          pending_artifact=""
          pending_line=0
          continue
        fi

        artifact_candidate=$pending_artifact
        if [[ "$artifact_candidate" == /* ]]; then
          record_result \
            "$aln_path" \
            "$pending_line" \
            "$pending_artifact" \
            "$declared_sha256" \
            "" \
            "failed" \
            "absolute artifact paths are not permitted"
          pending_artifact=""
          pending_line=0
          continue
        fi

        artifact_candidate="$repo_root/$artifact_candidate"
        if [[ ! -e "$artifact_candidate" ]]; then
          record_result \
            "$aln_path" \
            "$pending_line" \
            "$pending_artifact" \
            "$declared_sha256" \
            "" \
            "failed" \
            "referenced artifact does not exist"
          pending_artifact=""
          pending_line=0
          continue
        fi

        resolved_artifact=$(canonical_path "$artifact_candidate")
        if ! path_is_within_root "$repo_root" "$resolved_artifact"; then
          record_result \
            "$aln_path" \
            "$pending_line" \
            "$pending_artifact" \
            "$declared_sha256" \
            "" \
            "failed" \
            "referenced artifact resolves outside repository root"
          pending_artifact=""
          pending_line=0
          continue
        fi

        if [[ ! -f "$resolved_artifact" ]]; then
          record_result \
            "$aln_path" \
            "$pending_line" \
            "$resolved_artifact" \
            "$declared_sha256" \
            "" \
            "failed" \
            "referenced artifact is not a regular file"
          pending_artifact=""
          pending_line=0
          continue
        fi

        actual_sha256=$(sha256sum -- "$resolved_artifact" | awk '{print $1}')
        if [[ "$actual_sha256" == "$declared_sha256" ]]; then
          record_result \
            "$aln_path" \
            "$pending_line" \
            "$resolved_artifact" \
            "$declared_sha256" \
            "$actual_sha256" \
            "passed" \
            "digest matches"
        else
          record_result \
            "$aln_path" \
            "$pending_line" \
            "$resolved_artifact" \
            "$declared_sha256" \
            "$actual_sha256" \
            "failed" \
            "digest mismatch"
        fi

        pending_artifact=""
        pending_line=0
        ;;
      end)
        if [[ -n "$pending_artifact" ]]; then
          record_result \
            "$aln_path" \
            "$pending_line" \
            "$pending_artifact" \
            "" \
            "" \
            "failed" \
            "missing SHA256 declaration before END"
          pending_artifact=""
          pending_line=0
        fi
        ;;
    esac
  done < <(
    awk '
      /^[[:space:]]*ARTIFACT[[:space:]]+/ {
        line = $0
        sub(/^[[:space:]]*ARTIFACT[[:space:]]+/, "", line)
        print NR "\tartifact\t" line
        next
      }
      /^[[:space:]]*SHA256[[:space:]]+/ {
        line = $0
        sub(/^[[:space:]]*SHA256[[:space:]]+/, "", line)
        print NR "\tsha256\t" line
        next
      }
      /^[[:space:]]*END[[:space:]]*$/ {
        print NR "\tend\t"
      }
    ' "$aln_path"
  )

  if [[ -n "$pending_artifact" ]]; then
    record_result \
      "$aln_path" \
      "$pending_line" \
      "$pending_artifact" \
      "" \
      "" \
      "failed" \
      "missing SHA256 declaration at end of file"
  fi
done

overall_status="passed"
if ((failed_count > 0)); then
  overall_status="failed"
fi

json_report=$(
  {
    printf '{'
    printf '"schema_version":"%s",' "$REPORT_SCHEMA_VERSION"
    printf '"tool":"%s",' "$PROGRAM_NAME"
    printf '"repository_root":"%s",' "$(json_escape "$repo_root")"
    printf '"status":"%s",' "$overall_status"
    printf '"checked_count":%d,' "$checked_count"
    printf '"passed_count":%d,' "$passed_count"
    printf '"failed_count":%d,' "$failed_count"
    printf '"results":['
    local_separator=""
    for result in "${results[@]}"; do
      printf '%s%s' "$local_separator" "$result"
      local_separator=","
    done
    printf ']'
    printf '}\n'
  }
)

if [[ -n "$output_file" ]]; then
  output_parent=$(dirname -- "$output_file")
  mkdir -p -- "$output_parent"
  temporary_output="${output_file}.tmp.$$"
  umask 077
  printf '%s' "$json_report" > "$temporary_output"
  mv -- "$temporary_output" "$output_file"
else
  printf '%s' "$json_report"
fi

if [[ "$overall_status" == "passed" ]]; then
  exit 0
fi

exit 1
