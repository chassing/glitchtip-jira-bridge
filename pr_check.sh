#!/bin/bash
set -e

make test

export NO_PUSH=1
exec ./build_deploy.sh
