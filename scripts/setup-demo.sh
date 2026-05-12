#!/bin/bash

# Adapted from externalCode.yaml demo setup script
# Run this AFTER Terraform has created the AKS cluster, operators, and tenant namespace.

set -euo pipefail

TENANT_NAMESPACE="${TENANT_NAMESPACE:-tenant-1}"
MONGO_RESOURCE_NAME="${MONGO_RESOURCE_NAME:-tenant-1-mongodb}"
MDBUSERNAME="${MDBUSERNAME:-admin}"
MDBPASSWORD="${MDBPASSWORD:-mongodbpassword1}"

echo "*********************************************************"
echo "Setting up MongoDB demo environment in namespace: ${TENANT_NAMESPACE}"
echo "This will download sample data and load it into the replica set"
echo "*********************************************************"

echo "Downloading sample data archive..."
curl -L https://atlas-education.s3.amazonaws.com/sampledata.archive -o sampledata.archive

echo "Waiting 10 minutes for MongoDB to be ready before loading sample data"
sleep 600

POD_NAME="${MONGO_RESOURCE_NAME}-0"

echo "Port-forwarding pod/${POD_NAME} 27017 -> localhost:27017 in namespace ${TENANT_NAMESPACE}"
kubectl port-forward "pod/${POD_NAME}" 27017:27017 -n "${TENANT_NAMESPACE}" &
PF_PID=$!

sleep 5

cleanup() {
  echo "Stopping port-forward (pid=${PF_PID})"
  kill "${PF_PID}" 2>/dev/null || true
}
trap cleanup EXIT

for i in {1..20}; do
  echo "Attempt ${i}: running mongorestore..."
  if mongorestore --nsExclude admin.* --username "${MDBUSERNAME}" --password "${MDBPASSWORD}" --archive=sampledata.archive; then
    echo "mongorestore completed successfully"
    exit 0
  fi
  echo "mongorestore failed, retrying in 60 seconds..."
  sleep 60
done

echo "mongorestore failed after multiple attempts"
exit 1
