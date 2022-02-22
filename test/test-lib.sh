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

# Prevent sharness from adding the source directory to PATH
# since the scripts use unversioned python for their shebang
# but tests should run under the python with mercurial support
# so create an empty directory and strip it from PATH afterwards
SHARNESS_BUILD_DIRECTORY="$(mktemp -d)"
. "$SHARNESS"
export PATH="${PATH#*:}"
rmdir "$SHARNESS_BUILD_DIRECTORY"

if [ -z "$TEST_INSTALLED_SCRIPTS" ] ; then
	if [ -n "$PYTHON" ] && "$PYTHON" -c 'import mercurial' 2> /dev/null ; then
		: Use chosen Python version
	elif python3 -c 'import mercurial' 2> /dev/null ; then
		PYTHON=python3
	elif python2 -c 'import mercurial' 2> /dev/null ; then
		PYTHON=python2
	elif python -c 'import mercurial' 2> /dev/null ; then
		PYTHON=python
	fi
	if [ -n "$PYTHON" ] ; then
		test_set_prereq PYTHON

		# Change shebang on a copy of scripts to chosen Python version
		TEST_BIN="$SHARNESS_TRASH_DIRECTORY/bin"
		mkdir -p "$TEST_BIN"
		for s in git-remote-hg git-hg-helper ; do
			printf "%s\n" "#!/usr/bin/env $PYTHON" > "$TEST_BIN/$s"
			tail -n +2 "$SHARNESS_TEST_DIRECTORY/../$s" >> "$TEST_BIN/$s"
			chmod u+x "$TEST_BIN/$s"
		done
		export PATH="$TEST_BIN${PATH:+:$PATH}"
		unset TEST_BIN
	fi
else
	# The build/install process ensures Python is available
	test_set_prereq PYTHON
fi

GIT_AUTHOR_EMAIL=author@example.com
GIT_AUTHOR_NAME='A U Thor'
GIT_COMMITTER_EMAIL=committer@example.com
GIT_COMMITTER_NAME='C O Mitter'
export GIT_AUTHOR_EMAIL GIT_AUTHOR_NAME
export GIT_COMMITTER_EMAIL GIT_COMMITTER_NAME
# maintain backwards compatible default
# (as used in remote helper)
git config --global init.defaultBranch master
