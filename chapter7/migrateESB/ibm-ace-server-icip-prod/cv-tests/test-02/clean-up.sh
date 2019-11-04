#!/bin/bash

# Exit when failures occur (including unset variables)
set -o errexit
set -o nounset
set -o pipefail

printf "\n================================================================================\n"
printf " Running clean-up for ibm-ace-server-prod test-02\n"
printf "================================================================================\n\n"

# Helm delete of the content server
echo "Removing content server"
releaseName=ace-c-s-02-$(hostname | sha256sum| cut -c -10)
helm delete --purge $releaseName

# Delete the configuration secret for the server
echo "Deleting server configuration secret"
kubectl delete secret test02-secret
