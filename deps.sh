#!/bin/bash

set -o errexit
set -o pipefail

apt-get install -y fswebcam curl
chmod u+x ./dropbox_uploader.sh
