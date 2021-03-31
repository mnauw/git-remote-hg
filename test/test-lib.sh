#!/bin/sh

if [ -z "$SHARNESS" ] ; then
	for d in \
		"." \
		"$HOME/share/sharness" \
		"/usr/local/share/sharness" \
		"/usr/share/sharness"
	do
		f="$d/sharness.sh"
		if [ -f "$f" ] ; then
			SHARNESS="$f"
		fi
	done
fi
if [ -z "$SHARNESS" ] || [ ! -f "$SHARNESS" ] ; then
	echo "sharness.sh not found" >&2
	exit 1
fi

. "$SHARNESS"

test_set_prereq PYTHON

GIT_AUTHOR_EMAIL=author@example.com
GIT_AUTHOR_NAME='A U Thor'
GIT_COMMITTER_EMAIL=committer@example.com
GIT_COMMITTER_NAME='C O Mitter'
export GIT_AUTHOR_EMAIL GIT_AUTHOR_NAME
export GIT_COMMITTER_EMAIL GIT_COMMITTER_NAME
