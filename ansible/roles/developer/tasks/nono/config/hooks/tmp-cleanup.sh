#!/bin/sh
set -eu

# Receive the exact launcher-created path, not NONO_SESSION_ID.
[ "$#" -eq 1 ] || exit 1
SESSION_TMP=$1
case "$SESSION_TMP" in
    /tmp/nono-tmp/session.*) ;;
    *) echo "Refusing unexpected temporary path" >&2; exit 1 ;;
esac
SESSION_ID=${SESSION_TMP#/tmp/nono-tmp/session.}
[ "${#SESSION_ID}" -eq 12 ] || exit 1
case "$SESSION_ID" in
    *[!A-Za-z0-9]*) echo "Refusing invalid temporary ID" >&2; exit 1 ;;
esac
[ ! -L /tmp/nono-tmp ] || exit 1
[ "$(stat -c %u -- /tmp/nono-tmp)" = "$(id -u)" ] || exit 1
rm -rf -- "$SESSION_TMP"
