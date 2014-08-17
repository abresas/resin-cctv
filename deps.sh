#!/bin/bash

set -o errexit
set -o pipefail

apt-get install -y fswebcam curl ttf-freefont ttf-liberation ttf-dejavu
chmod u+x ./dropbox_uploader.sh
