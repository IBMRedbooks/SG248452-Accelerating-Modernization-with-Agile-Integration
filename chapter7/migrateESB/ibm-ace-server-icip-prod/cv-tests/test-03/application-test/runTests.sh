#!/bin/bash
#
# runTests script REQUIRED ONLY IF additional application verification is
# needed above and beyond helm tests.
#
# Parameters :
#   -c <chartReleaseName>, the name of the release used to install the helm chart
#
# Pre-req environment: authenticated to cluster, kubectl cli install / setup complete, & chart installed

# Exit when failures occur (including unset variables)
set -o errexit
set -o nounset
set -o pipefail

printf "\n================================================================================\n"
printf " Running ibm-ace-server-dev test-03\n"
printf "================================================================================\n\n"

# Parameters
# Below is the current set of parameters which are passed in to the app test script.
# The script can process or ignore the parameters
# The script can be coded to expect the parameter list below, but should not be coded such that additional parameters
# will cause the script to fail
#   -e <environment>, IP address of the environment
#   -c <chart release name>, release name specified on chart installation
#   -r <release>, ie V.R.M.F-tag, the release notation associated with the environment, this will be V.R.M.F, plus an option -tag
#   -a <architecture>, the architecture of the environment
#   -u <userid>, the admin user id for the environment
#   -p <password>, the password for accessing the environment, base64 encoded, p=`echo p_enc | base64 -d` to decode the password when using

# Verify pre-req environment
command -v kubectl > /dev/null 2>&1 || { echo "kubectl pre-req is missing."; exit 1; }
command -v curl > /dev/null 2>&1 || { echo "curl pre-req is missing."; exit 1; }

# Setup and execute application test on installation
echo "Running application test"

# Process parameters notify of any unexpected
while test $# -gt 0; do
	[[ $1 =~ ^-c|--chartrelease$ ]] && { chartRelease="$2"; shift 2; continue; };
    echo "Parameter not recognized: $1, ignored"
    shift
done
: "${chartRelease:="default"}"

podName=$(kubectl get pods -l release=${chartRelease} -o jsonpath='{.items[0].metadata.name}')
[[ ${podName} =~ ${chartRelease} ]] && echo "pod name is ${podName}"

sumOfReturnCodes=0

echo "Stage1: Set up port-forwarding"
echo "----------------------------"

# Check that the pod is running
kubectl get pods ${podName} | grep Running ||
{ echo 'Pod is not running'; sumOfReturnCodes=$((sumOfReturnCodes + 1)); }

# Start port forawrding
echo "Forwarding REST API to ${podName}"
kubectl port-forward ${podName} 7600:7600 &
portForwardPID=$!

echo "Waiting for port forwarding to start"
i=0
while [ $i -le "20" ]
do
  sleep 1
  echo -n "."
  i=$(($i+1))
  netstat -tan | grep -q 7600 && break
done
sleep 3
echo ""

netstat -tan | grep -q 7600 || { echo "Listener not started"; exit 1; }

echo "port forwarder running.  PID=${portForwardPID}"

echo "Stage2: Check the webui"
echo "----------------------------"

echo "S2-T1: GET /apiv2 (GET https://localhost:7600/apiv2)"
echo " - Should return 200"
HTTP_CODE=$(curl -X GET --silent --output /dev/null --write-out "%{http_code}" http://localhost:7600/apiv2)
echo " - Got return code ${HTTP_CODE}"
if [ "${HTTP_CODE}" = "200" ]; then code=0; else code=1; fi
sumOfReturnCodes=$((sumOfReturnCodes + ${code})); echo "Result S2-T1: ${code}";


echo "Stop forwarding HTTP to ${podName}"
kill ${portForwardPID}

if [ $sumOfReturnCodes -eq 0 ]; then echo "Test run passed"; fi
printf "\n================================================================================\n"

exit $sumOfReturnCodes
