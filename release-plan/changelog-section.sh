#!/usr/bin/env bash
set -euo pipefail

version=${1:?usage: changelog-section.sh <version> [changelog]}
changelog=${2:-CHANGELOG.md}

section=$(awk -v heading="## [$version]" '
	index($0, "## [") == 1 { if (found) exit; found = index($0, heading) == 1; next }
	/^\[[^]]+\]: / { if (found) exit }
	found { lines[++count] = $0; if ($0 ~ /[^[:space:]]/) { if (!first) first = count; last = count } }
	END { for (i = first; first && i <= last; i++) print lines[i] }
' "$changelog")

if [[ -z "$section" ]]; then
	echo "$changelog has no section for $version: add its release heading (## [$version] - <date>) first" >&2
	exit 1
fi

printf '%s\n' "$section"
