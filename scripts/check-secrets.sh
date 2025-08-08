#!/usr/bin/env bash
set -euo pipefail

scan_type=${1-pre-commit}

if ! git secrets -- 1> /dev/null; then
  echo "git secrets is not installed"
  echo "the git-secrets file needs to be in your PATH"
  echo "to install:"
  echo "  wget https://raw.githubusercontent.com/awslabs/git-secrets/refs/heads/master/git-secrets -O ~/.local/bin/git-secrets && chmod +x ~/.local/bin/git-secrets"
  exit 1
fi

echo "scan type: ${scan_type}"

git secrets --register-aws
if [[ -e ./.gitdisallowed ]]; then
  git secrets --add-provider -- grep -Ev '^(#.*|\s*$)' .gitdisallowed || true
  git secrets --add --allowed '^\.gitdisallowed:[0-9]+:.*' || true
fi

if { [ "${scan_type}" == "unstaged" ]; } ; then
  echo "scanning staged and unstaged files for secrets"
  git secrets --scan --recursive
  git secrets --scan --untracked
elif { [ "${scan_type}" == "staged" ]; } ; then
  echo "scanning staged files for secrets"
  git secrets --scan --recursive
elif { [ "${scan_type}" == "commit-msg" ]; } ; then
  echo "checking commit msg for secrets"
  git secrets --commit_msg_hook -- "${2}"
elif { [ "${scan_type}" == "prep-commit-msg" ]; } ; then
  echo "checking commit msg for secrets"
  git secrets --prepare_commit_msg_hook -- "${2}"
else
  echo "scanning for secrets"
  # if staged files exist, this will scan staged files only, otherwise normal scan
  git secrets --pre_commit_hook
fi
