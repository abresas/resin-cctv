#!/bin/bash

set -o errexit
set -o pipefail

apt-get install -y motion
mkdir /tmp/camera
cp config/motion.conf /etc/motion/motion.conf
service motion start
