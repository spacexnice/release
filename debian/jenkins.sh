#!/bin/bash

set -o nounset
set -o errexit
set -o nounset
set -o xtrace


declare -r BUILD_TAG="$(date '+%y%m%d%H%M%S')"
declare -r IMG_NAME="debian-builder:${BUILD_TAG}"
declare -r DEB_RELEASE_BUCKET="gs://kubernetes-release-dev/debian"

docker build -t "${IMG_NAME}" debian/
docker run --rm -e KUBE_BASEDOWNLOAD_LINK=http://aliacs-k8s.oss-cn-hangzhou.aliyuncs.com/binary/amd64/1.6.0-alpha-88fbc68 -v "${PWD}/bin:/src/bin" "${IMG_NAME}"

gsutil -m cp -nrc bin "${DEB_RELEASE_BUCKET}/${BUILD_TAG}"
gsutil -m cp <(printf "${BUILD_TAG}") "${DEB_RELEASE_BUCKET}/latest"
