#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

# desired cluster name; default is "knative"
KIND_CLUSTER_NAME="${KIND_CLUSTER_NAME:-knative}"

if [[ "$(kind get clusters)" =~ .*"${KIND_CLUSTER_NAME}".* ]]; then
  echo "cluster already exists, moving on"
  exit 0
fi

kind create cluster --name "${KIND_CLUSTER_NAME}" --config=./config/kind-config.yml

kubectl wait node "${KIND_CLUSTER_NAME}-control-plane" --for=condition=ready --timeout=90s
