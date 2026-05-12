#!/bin/bash

# Simple helper to load Atlas sample data into a MongoDB deployment.
# Assumes you already have a port-forward to localhost:27017.

set -euo pipefail

MDBUSERNAME="${MDBUSERNAME:-admin}"
MDBPASSWORD="${MDBPASSWORD:-mongodbpassword1}"

curl -L https://atlas-education.s3.amazonaws.com/sampledata.archive -o sampledata.archive

mongorestore --nsExclude admin.* --username "${MDBUSERNAME}" --password "${MDBPASSWORD}" --archive=sampledata.archive
