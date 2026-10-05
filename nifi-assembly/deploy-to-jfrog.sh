#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
#
# Builds the nifi-assembly module and deploys the resulting "bin.zip"
# distribution archive to the JFrog Artifactory snapshot repository.
#
# The maven-assembly-plugin execution that produces the bin.zip in
# nifi-assembly/pom.xml has <attach>false</attach>, so a plain
# "mvn deploy" never uploads it. This script builds the module and then
# explicitly deploys the archive with "mvn deploy:deploy-file", using the
# same naming convention Artifactory applies to regular deployed
# snapshots (artifactId-version-timestamp-buildNumber-bin.zip).
#
# Usage:
#   ./deploy-to-jfrog.sh [skip-build]
#
#   skip-build   Optional. Pass this to skip the "mvn clean deploy" build
#                step and only deploy an already-built target/*-bin.zip.
#
# Requires Maven credentials for the "snapshots" server id to be
# configured in ~/.m2/settings.xml, matching the repository defined in
# the parent pom's <distributionManagement>.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
MODULE_DIR="${SCRIPT_DIR}"

REPOSITORY_ID="${REPOSITORY_ID:-snapshots}"
REPOSITORY_URL="${REPOSITORY_URL:-https://vf01artifactory.jfrog.io/artifactory/vfcz-intg-java-snapshot}"

SKIP_BUILD="${1:-}"

cd "${REPO_ROOT}"

if [[ "${SKIP_BUILD}" != "skip-build" ]]; then
    echo "==> Building nifi-assembly (mvn clean deploy -pl nifi-assembly -am)"
    mvn -pl nifi-assembly -am \
        -DskipTests=true \
        -Dspotless.check.skip=true \
        -Dlicense.skip=true \
        -Dcheckstyle.skip=true \
        clean deploy
else
    echo "==> Skipping build, reusing existing target/*-bin.zip"
fi

BIN_ZIP="$(find "${MODULE_DIR}/target" -maxdepth 1 -name 'nifi-*-bin.zip' | head -n 1)"

if [[ -z "${BIN_ZIP}" ]]; then
    echo "ERROR: Could not find a built nifi-*-bin.zip under ${MODULE_DIR}/target" >&2
    exit 1
fi

echo "==> Found archive: ${BIN_ZIP}"
echo "==> Deploying to ${REPOSITORY_URL}"

mvn deploy:deploy-file \
    "-Dfile=${BIN_ZIP}" \
    "-DpomFile=${MODULE_DIR}/pom.xml" \
    "-Dclassifier=bin" \
    "-Dpackaging=zip" \
    "-DrepositoryId=${REPOSITORY_ID}" \
    "-Durl=${REPOSITORY_URL}"

echo "==> Deploy complete."
