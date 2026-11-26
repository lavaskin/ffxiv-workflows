#!/usr/bin/env bash
set -uo pipefail

scripts=$(cd "$(dirname "$0")/../release-plan" && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
failures=0

pass() { echo "ok   $1"; }
fail() { echo "FAIL $1"; failures=$((failures + 1)); }

expect_output() {
	local name=$1 expected=$2
	shift 2
	local actual
	if ! actual=$("$@" 2>"$work/stderr"); then
		fail "$name: exited $?: $(cat "$work/stderr")"
	elif [[ $actual != "$expected" ]]; then
		fail "$name: expected"$'\n'"$expected"$'\n'"got"$'\n'"$actual"
	else
		pass "$name"
	fi
}

expect_failure() {
	local name=$1 message=$2
	shift 2
	if "$@" >/dev/null 2>"$work/stderr"; then
		fail "$name: succeeded"
	elif ! grep -qF "$message" "$work/stderr"; then
		fail "$name: expected an error with \"$message\", got: $(cat "$work/stderr")"
	else
		pass "$name"
	fi
}

cat >"$work/CHANGELOG.md" <<'EOF'
# Changelog

## [Unreleased]

## [1.0.10] - 2026-11-20

### Added

- Ten.

## [1.0.1] - 2026-11-10


### Fixed

- One.


## [1.0.0] - 2026-11-01

### Added

- The first.

## [0.9.0] - 2026-10-01

[Unreleased]: https://example.com/compare/v1.0.10...HEAD
[1.0.10]: https://example.com/compare/v1.0.1...v1.0.10
EOF

expect_output "changelog: a section, trimmed of blank lines at both ends" $'### Fixed\n\n- One.' \
	"$scripts/changelog-section.sh" 1.0.1 "$work/CHANGELOG.md"
expect_output "changelog: 1.0.1 isn't read as 1.0.10" $'### Added\n\n- Ten.' \
	"$scripts/changelog-section.sh" 1.0.10 "$work/CHANGELOG.md"
expect_output "changelog: the last section stops at the next heading" $'### Added\n\n- The first.' \
	"$scripts/changelog-section.sh" 1.0.0 "$work/CHANGELOG.md"
expect_failure "changelog: no section" "has no section for 2.0.0" \
	"$scripts/changelog-section.sh" 2.0.0 "$work/CHANGELOG.md"
expect_failure "changelog: an empty section before the links" "has no section for 0.9.0" \
	"$scripts/changelog-section.sh" 0.9.0 "$work/CHANGELOG.md"
expect_failure "changelog: an empty section before the next heading" "has no section for Unreleased" \
	"$scripts/changelog-section.sh" Unreleased "$work/CHANGELOG.md"

git init -q --bare "$work/remote.git"
git -C "$work/remote.git" symbolic-ref HEAD refs/heads/main
git init -q "$work/repo"
git -C "$work/repo" -c user.name=test -c user.email=test@example.com commit -q --allow-empty -m first
git -C "$work/repo" tag v1.0.0
git -C "$work/repo" push -q "$work/remote.git" HEAD:refs/heads/main v1.0.0

expect_output "release: a version not tagged yet" release \
	"$scripts/release-action.sh" 1.1.0 "version in package.json" "$work/remote.git"
expect_output "release: a version already tagged" none \
	"$scripts/release-action.sh" 1.0.0 "version in package.json" "$work/remote.git"
expect_failure "release: a version that isn't X.Y.Z" "The version, 1.0, isn't X.Y.Z: fix version in package.json" \
	"$scripts/release-action.sh" 1.0 "version in package.json" "$work/remote.git"
expect_failure "release: a remote that can't be read" "Couldn't read" \
	"$scripts/release-action.sh" 1.0.0 "version in package.json" "$work/missing.git"

if ((failures)); then
	echo "$failures failed"
	exit 1
fi
