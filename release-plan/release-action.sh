#!/usr/bin/env bash
set -euo pipefail

usage='usage: release-action.sh <version> <version file> [remote]'
version=${1:?$usage}
version_file=${2:?$usage}
remote=${3:-origin}
tag=v$version

if [[ ! $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
	echo "The version, $version, isn't X.Y.Z: fix $version_file" >&2
	exit 1
fi

status=0
git ls-remote --exit-code --tags "$remote" "refs/tags/$tag" >/dev/null || status=$?
if ((status == 2)); then
	echo release
elif ((status == 0)); then
	echo none
else
	echo "Couldn't read $remote's tags (git ls-remote exited $status)" >&2
	exit 1
fi
