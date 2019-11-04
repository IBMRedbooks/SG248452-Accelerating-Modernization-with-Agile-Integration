#!/bin/bash

# Exit when failures occur (including unset variables)
set -o errexit
set -o nounset
set -o pipefail

printf "\n================================================================================\n"
printf " Running pre-install for ibm-ace-server-prod test-01\n"
printf "================================================================================\n\n"

# Verify pre-req environment
echo "Checking that required tools are installed"
command -v kubectl > /dev/null 2>&1 || { echo "kubectl pre-req is missing."; exit 1; }
command -v helm > /dev/null 2>&1 || { echo "helm pre-req is missing."; exit 1; }
command -v curl > /dev/null 2>&1 || { echo "curl pre-req is missing."; exit 1; }
command -v netstat > /dev/null 2>&1 || { echo "netstat pre-req is missing."; exit 1; }

[[ `dirname $0 | cut -c1` = '/' ]] && preinstallDir=`dirname $0`/ || preinstallDir=`pwd`/`dirname $0`/
export preinstallDir

# Helm install of content server
releaseName=ace-c-s-01-$(hostname | sha256sum| cut -c -10)
echo "Installing a content server as release ${releaseName}"
helm install --name ${releaseName} ${preinstallDir}/content-server --wait --timeout 120

# Find the content server url
podName=$(kubectl get pods -l release=${releaseName} -o jsonpath='{.items[0].metadata.name}')
[[ ${podName} =~ ${releaseName} ]] && echo "pod name is ${podName}"
serviceName=$(kubectl get services -l release=${releaseName} -o jsonpath='{.items[0].metadata.name}')
[[ ${serviceName} =~ ${releaseName} ]] && echo "service name is ${serviceName}"

# Wait for pod to be ready, as helm --wait is unreliable.  Wait up to 60 seconds
echo "Waiting for pod to start"
i=0
while [ $i -le "90" ]
do
  sleep 3
  echo -n "."
  i=$(($i+1))
  [[ "$(kubectl get pod ${podName} -o jsonpath='{.status.containerStatuses[0].ready}')" == "true" ]] && break
done
echo ""

if [[ "$(kubectl get pod ${podName} -o jsonpath='{.status.containerStatuses[0].ready}')" != "true" ]]; then
  echo "Pods not started, logs from pod are below:"
  kubectl logs ${podName}
  exit 1
fi

i=0
portForwardingSuccessful=false
while [ $i -le "20" ]
do
  i=$(($i+1))
  # Start port forawrding
  echo "Forwarding HTTP to ${podName} (attempt ${i})"
  kubectl port-forward ${podName} 3443:3443 &
  portForwardPID=$!

  echo "Waiting for port forwarding to start"
  j=0
  while [ $j -le "20" ]
  do
    sleep 1
    echo -n "."
    j=$(($j+1))
    netstat -tan | grep -q 3443 && portForwardingSuccessful=true && break
  done

  if [ "${portForwardingSuccessful}" = true ]; then
    echo "Port 3443 found..."
    break
  else
    kill ${portForwardPID} || echo "kubectl port-forwarding command already exited"
    echo "Listener not started... retrying..."
  fi
done

sleep 5
echo ""

if [ "$portForwardingSuccessful" = false ]; then
  echo "Listener not started after ${i} attempts"
  exit 1
fi

echo "port forwarder running.  PID=${portForwardPID}"

# Curl create a directory and post a bar file
echo "Creating a directory"
echo "Calling curl -X PUT -k -H \"x-ibm-ace-control-apikey: control-server-test-api-key\" https://localhost:3443/v1/directories/testdir"
directoryToken=$(curl -X PUT -k -H "x-ibm-ace-control-apikey: control-server-test-api-key" https://localhost:3443/v1/directories/testdir | sed -e 's/.*"token":"\([^"]\+\)".*/\1/')

if ! [[ ${directoryToken} =~ [0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12} ]]; then
  echo "Error creating a directory.  I expected a directory with a token that is a uuid, but got ${directoryToken}"
  echo "Stop forwarding HTTP to ${podName}"
  kill ${portForwardPID}
fi
echo "Directory created, directoryToken=${directoryToken}"

echo "Uploading a bar file"
curl -X PUT -k -H "x-ibm-ace-control-apikey: control-server-test-api-key" https://localhost:3443/v1/directories/testdir/bars/TestFlows.bar --data-binary @${preinstallDir}/bar/TestFlows.bar
echo "Bar file uploaded"

echo "Stop forwarding HTTP to ${podName}"
kill ${portForwardPID}

contentServerURL="https://${serviceName}:3443/v1/directories/testdir?${directoryToken}"
echo "Recording the contentServerURL value ${contentServerURL}"
echo "contentServerURL: \"${contentServerURL}\"" >> ${preinstallDir}/../values.yaml

# Create the configuration secret for the server
echo "Creating server configuration secret"
cd ${preinstallDir}/config
./generateSecrets.sh test01-secret
