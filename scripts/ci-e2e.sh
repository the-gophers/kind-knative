#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

REPO_ROOT=$(dirname "${BASH_SOURCE[0]}")/..
cd "${REPO_ROOT}" || exit 1

defaultTag=$(date -u '+%Y%m%d%H%M%S')
export TAG="${defaultTag:-dev}"

make test-e2e
