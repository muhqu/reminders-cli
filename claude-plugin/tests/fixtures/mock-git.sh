#!/bin/sh

[ "${1-}" = "-C" ] || exit 10
[ "${3-}" = "remote" ] || exit 11
[ "${4-}" = "get-url" ] || exit 12
[ "${5-}" = "origin" ] || exit 13
printf '%s\n' "$MOCK_REPO"
