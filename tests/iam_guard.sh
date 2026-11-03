#!/usr/bin/env bash
# Checks that the agent can't modify its own IAM, this module's IAM, or another deployment's, and that
# the check itself still catches the regressions it exists for. Needs terraform and python3; makes no
# AWS calls. Run from anywhere: tests/iam_guard.sh
set -euo pipefail

# The module just before the agent self-write fix (#58). It still has the redpanda-* wildcards from
# PR #30 that let the agent rewrite its own policies and trust policy, so the check must fail on it.
PRE_FIX_REF=994e9c9f647262f48b67006567e3483af5b16260

DENY_SIDS=(RedpandaAgentDenyCustomerOwnedIAMWrites RedpandaAgentDenyModuleOwnedIAMWrites)

repo=$(cd "$(dirname "$0")/.." && pwd)
work=$(mktemp -d)
pre_fix_tree="$work/pre-fix"
trap 'git -C "$repo" worktree remove --force "$pre_fix_tree" 2>/dev/null || true; rm -rf "$work"' EXIT

guard() { python3 "$repo/tests/iam_guard.py" "$@"; }

# Exit status 1 means violations were found; 2 means the input couldn't be evaluated, which must not
# count as the expected failure.
expect_violations() {
  local status=0
  guard "$@" >"$work/expected-fail.txt" || status=$?
  if [ "$status" -ne 1 ]; then
    cat "$work/expected-fail.txt"
    echo "FAIL: expected violations (exit 1), got exit $status: iam_guard.py $*" >&2
    exit 1
  fi
  grep '^\[' "$work/expected-fail.txt"
}

# Terraform runs without AWS credentials, so a provisioner that shells out to the AWS CLI fails
# instead of acting on whatever account the caller's shell points at.
no_aws() {
  env -u AWS_PROFILE -u AWS_DEFAULT_PROFILE -u AWS_ACCESS_KEY_ID -u AWS_SECRET_ACCESS_KEY \
    -u AWS_SESSION_TOKEN -u AWS_WEB_IDENTITY_TOKEN_FILE -u AWS_ROLE_ARN \
    AWS_CONFIG_FILE=/dev/null AWS_SHARED_CREDENTIALS_FILE=/dev/null AWS_EC2_METADATA_DISABLED=true "$@"
}

render() {
  local dir=$1 out=$2
  no_aws terraform -chdir="$dir" init -backend=false -input=false >/dev/null
  # Failures are reported by iam_guard.py, which prints the error diagnostics from this output.
  no_aws terraform -chdir="$dir" test -filter=tests/iam_guard.tftest.hcl -json -verbose >"$out" || true
}

echo "--- Current module: no violations"
render "$repo" "$work/current.json"
guard "$work/current.json"

echo "--- Current module with iam:* allowed: the Deny statements alone protect everything"
guard --assume-allow-all "$work/current.json"

for sid in "${DENY_SIDS[@]}"; do
  echo "--- Current module with iam:* allowed and $sid removed: violations"
  expect_violations --assume-allow-all --drop-sid "$sid" "$work/current.json"
done

echo "--- Module before the self-write fix ($PRE_FIX_REF): violations"
git -C "$repo" worktree add --quiet --detach "$pre_fix_tree" "$PRE_FIX_REF"
mkdir -p "$pre_fix_tree/tests"
cp "$repo/tests/iam_guard.tftest.hcl" "$pre_fix_tree/tests/"
render "$pre_fix_tree" "$work/pre-fix.json"
expect_violations "$work/pre-fix.json"

echo "--- OK"
