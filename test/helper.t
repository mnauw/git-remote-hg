#!/bin/sh
#
# Copyright (c) 2016 Mark Nauwelaerts
#
# Base commands from hg-git tests:
# https://bitbucket.org/durin42/hg-git/src
#

test_description='Test git-hg-helper'

test -n "$TEST_DIRECTORY" || TEST_DIRECTORY=$(dirname $0)/
. "$TEST_DIRECTORY"/test-lib.sh

if ! test_have_prereq PYTHON
then
	skip_all='skipping remote-hg tests; python not available'
	test_done
fi

if ! python -c 'import mercurial' > /dev/null 2>&1
then
	skip_all='skipping remote-hg tests; mercurial not available'
	test_done
fi

setup () {
	cat > "$HOME"/.hgrc <<-EOF &&
	[ui]
	username = H G Wells <wells@example.com>
	[extensions]
	mq =
	strip =
	[subrepos]
	git:allowed = true
	EOF

	GIT_AUTHOR_DATE="2007-01-01 00:00:00 +0230" &&
	GIT_COMMITTER_DATE="$GIT_AUTHOR_DATE" &&
	export GIT_COMMITTER_DATE GIT_AUTHOR_DATE
}

setup

setup_repos () {
	(
	hg init hgrepo &&
	cd hgrepo &&
	echo zero > content &&
	hg add content &&
	hg commit -m zero
	) &&

	git clone hg::hgrepo gitrepo
}

test_expect_success 'subcommand help' '
	test_when_finished "rm -rf gitrepo* hgrepo*" &&

	setup_repos &&

	(
	cd gitrepo &&
	test_expect_code 2 git-hg-helper help 2> ../help
	)
	# remotes should be in help output
	grep origin help
'

git config --global remote-hg.shared-marks false
test_expect_success 'subcommand repo - no local proxy' '
	test_when_finished "rm -rf gitrepo* hgrepo*" &&

	setup_repos &&

	(
	cd hgrepo &&
	pwd >../expected
	) &&

	(
	cd gitrepo &&
	git-hg-helper repo origin > ../actual
	) &&

	test_cmp expected actual
'

git config --global --unset remote-hg.shared-marks

GIT_REMOTE_HG_TEST_REMOTE=1 &&
export GIT_REMOTE_HG_TEST_REMOTE

test_expect_success 'subcommand repo - with local proxy' '
	test_when_finished "rm -rf gitrepo* hgrepo*" &&

	setup_repos &&

	(
	cd gitrepo &&
	export gitdir=`git rev-parse --git-dir`
	# trick to normalize path
	( cd $gitdir/hg/origin/clone && pwd ) >../expected &&
	( cd `git-hg-helper repo origin` && pwd ) > ../actual
	) &&

	test_cmp expected actual
'

test_expect_success 'subcommands hg-rev and git-rev' '
	test_when_finished "rm -rf gitrepo* hgrepo*" &&

	setup_repos &&

	(
	cd gitrepo &&
	git rev-parse HEAD > rev-HEAD &&
	test -s rev-HEAD &&
	git-hg-helper hg-rev `cat rev-HEAD` > hg-HEAD &&
	git-hg-helper git-rev `cat hg-HEAD` > git-HEAD &&
	test_cmp rev-HEAD git-HEAD
	)
'

test_expect_success 'subcommand gc' '
	test_when_finished "rm -rf gitrepo* hgrepo*" &&

	(
	hg init hgrepo &&
	cd hgrepo &&
	echo zero > content &&
	hg add content &&
	hg commit -m zero
	echo one > content &&
	hg commit -m one &&
	echo two > content &&
	hg commit -m two &&
	echo three > content &&
	hg commit -m three
	) &&

	git clone hg::hgrepo gitrepo &&

	(
	cd hgrepo &&
	hg strip -r 1 &&
	echo four > content &&
	hg commit -m four
	) &&

	(
	cd gitrepo &&
	git fetch origin &&
	git reset --hard origin/master &&
	git gc &&
	git-hg-helper gc --check-hg origin > output &&
	cat output &&
	grep "hg marks" output &&
	grep "git marks" output
	)
'

test_expect_success 'subcommand [some-repo]' '
	test_when_finished "rm -rf gitrepo* hgrepo*" &&

	setup_repos &&

	(
	cd hgrepo &&
	echo one > content &&
	hg commit -m one
	) &&

	(
	cd gitrepo &&
	git fetch origin
	) &&

	hg log -R hgrepo > expected &&
	# not inside gitrepo; test shared path handling
	GIT_DIR=gitrepo/.git git-hg-helper origin log > actual

	test_cmp expected actual
'

setup_repo () {
    kind=$1 &&
    repo=$2 &&
    $kind init $repo &&
    (
    cd $repo &&
    echo zero > content_$repo &&
    $kind add content_$repo &&
    $kind commit -m zero_$repo
    )
}

check () {
	echo $3 > expected &&
	git --git-dir=$1/.git log --format='%s' -1 $2 > actual &&
	test_cmp expected actual
}

check_branch () {
	if test -n "$3"
	then
		echo $3 > expected &&
		hg -R $1 log -r $2 --template '{desc}\n' > actual &&
		test_cmp expected actual
	else
		hg -R $1 branches > out &&
		! grep $2 out
	fi
}

test_expect_success 'subcommand sub initial update (hg and git subrepos)' '
	test_when_finished "rm -rf gitrepo* hgrepo*" &&

	setup_repo hg hgrepo &&
	(
	cd hgrepo &&
	setup_repo hg sub_hg_a &&
	setup_repo hg sub_hg_b &&
	setup_repo git sub_git &&
	echo "sub_hg_a = sub_hg_a" > .hgsub &&
	echo "sub_hg_b = sub_hg_b" >> .hgsub &&
	echo "sub_git = [git]sub_git" >> .hgsub &&
	hg add .hgsub &&
	hg commit -m substate
	)

	git clone hg::hgrepo gitrepo &&

	(
	cd gitrepo &&
	git-hg-helper sub update --force &&
	test -f content_hgrepo &&
	test -f sub_hg_a/content_sub_hg_a &&
	test -f sub_hg_b/content_sub_hg_b &&
	test -f sub_git/content_sub_git
	) &&

	check gitrepo HEAD substate &&
	check gitrepo/sub_hg_a HEAD zero_sub_hg_a &&
	check gitrepo/sub_hg_b HEAD zero_sub_hg_b &&
	check gitrepo/sub_git HEAD zero_sub_git
'

setup_subrepos () {
	setup_repo hg hgrepo &&
	(
	cd hgrepo &&
	setup_repo hg sub_hg_a &&
		(
		cd sub_hg_a &&
		setup_repo hg sub_hg_a_x &&
		echo "sub_hg_a_x = sub_hg_a_x" > .hgsub &&
		hg add .hgsub &&
		hg commit -m substate_hg_a
		) &&
	setup_repo hg sub_hg_b &&
		(
		cd sub_hg_b &&
		setup_repo git sub_git &&
		echo "sub_git = [git]sub_git" > .hgsub &&
		hg add .hgsub &&
		hg commit -m substate_hg_b
		) &&
	echo "sub_hg_a = sub_hg_a" > .hgsub &&
	echo "sub_hg_b = sub_hg_b" >> .hgsub &&
	hg add .hgsub &&
	hg commit -m substate
	)
}

test_expect_success 'subcommand sub initial recursive update' '
	test_when_finished "rm -rf gitrepo* hgrepo*" &&

	setup_subrepos &&

	git clone hg::hgrepo gitrepo &&

	(
	cd gitrepo &&
	git-hg-helper sub --recursive update --force &&
	test -f content_hgrepo &&
	test -f sub_hg_a/content_sub_hg_a &&
	test -f sub_hg_a/sub_hg_a_x/content_sub_hg_a_x &&
	test -f sub_hg_b/content_sub_hg_b &&
	test -f sub_hg_b/sub_git/content_sub_git
	) &&

	check gitrepo HEAD substate &&
	check gitrepo/sub_hg_a HEAD substate_hg_a &&
	check gitrepo/sub_hg_b HEAD substate_hg_b &&
	check gitrepo/sub_hg_a/sub_hg_a_x HEAD zero_sub_hg_a_x &&
	check gitrepo/sub_hg_b/sub_git HEAD zero_sub_git
'

test_sub_update () {
	export option=$1

	setup_subrepos &&

	git clone hg::hgrepo gitrepo &&

	(
	cd gitrepo &&
	git-hg-helper sub --recursive update --force
	) &&

	(
	cd hgrepo &&
		(
		 cd sub_hg_a &&
			(
			cd sub_hg_a_x &&
			echo one > content_sub_hg_a_x &&
			hg commit -m one_sub_hg_a_x
			) &&
		hg commit -m substate_updated_hg_a
		) &&
	hg commit -m substate_updated
	) &&

	(
	cd gitrepo &&
	git fetch origin &&
	git merge origin/master &&
	git-hg-helper sub --recursive update --force $option &&
	test -f content_hgrepo &&
	test -f sub_hg_a/content_sub_hg_a &&
	test -f sub_hg_a/sub_hg_a_x/content_sub_hg_a_x &&
	test -f sub_hg_b/content_sub_hg_b &&
	test -f sub_hg_b/sub_git/content_sub_git
	) &&

	check gitrepo HEAD substate_updated &&
	check gitrepo/sub_hg_a HEAD substate_updated_hg_a &&
	check gitrepo/sub_hg_b HEAD substate_hg_b &&
	check gitrepo/sub_hg_a/sub_hg_a_x HEAD one_sub_hg_a_x &&
	check gitrepo/sub_hg_b/sub_git HEAD zero_sub_git
}

test_expect_success 'subcommand sub subsequent recursive update' '
	test_when_finished "rm -rf gitrepo* hgrepo*" &&

	test_sub_update
'

test_expect_success 'subcommand sub subsequent recursive update -- rebase' '
	test_when_finished "rm -rf gitrepo* hgrepo*" &&

	test_sub_update --rebase
'

test_expect_success 'subcommand sub subsequent recursive update -- merge' '
	test_when_finished "rm -rf gitrepo* hgrepo*" &&

	test_sub_update --merge
'

check_foreach_vars () {
	cat $1 | while read kind sha1 rev path remainder
	do
	    ok=0
	    if test "$kind" = "hg" ; then
			if test "$sha1" != "$rev" ; then
				ok=1
			fi
	    else
			if test "$sha1" = "$rev" ; then
				ok=1
			fi
	    fi
	    test $ok -eq 1 || echo "invalid $kind $sha1 $rev $path"
	    test $ok -eq 1 || return 1
	done &&

	return 0
}

test_sub_foreach () {
	setup_subrepos &&

	git clone hg::hgrepo gitrepo &&

	(
	cd gitrepo &&
	git-hg-helper sub --recursive update --force &&
	git-hg-helper sub --recursive --quiet foreach 'echo $kind $sha1 $rev $path $toplevel' > output &&
	cat output &&
	echo 1 > expected_git &&
	grep -c ^git output > actual_git &&
	test_cmp expected_git actual_git &&
	echo 3 > expected_hg &&
	grep -c ^hg output > actual_hg &&
	test_cmp expected_hg actual_hg &&
	grep '\(hg\|git\) [0-9a-f]* [0-9a-f]* sub[^ ]* /.*' output > actual &&
	test_cmp output actual &&
	check_foreach_vars output
	)
}

test_expect_success 'subcommand sub foreach' '
	test_when_finished "rm -rf gitrepo* hgrepo*" &&

	test_sub_foreach
'

test_expect_success 'subcommand sub sync' '
	test_when_finished "rm -rf gitrepo* hgrepo*" &&

	setup_repo hg hgrepo &&
	(
	cd hgrepo &&
	setup_repo hg sub_hg &&
	echo "sub_hg = sub_hg" > .hgsub &&
	hg add .hgsub &&
	hg commit -m substate
	)

	git clone hg::hgrepo gitrepo &&

	(
	cd gitrepo &&
	git-hg-helper sub update --force &&

		(
		cd sub_hg &&
		grep url .git/config > ../expected &&
		git config remote.origin.url foobar &&
		grep foobar .git/config
		) &&

	git-hg-helper sub sync &&
	grep url sub_hg/.git/config > actual &&
	test_cmp expected actual
	)
'

test_expect_success 'subcommand sub addstate' '
	test_when_finished "rm -rf gitrepo* hgrepo*" &&

	setup_repo hg hgrepo &&
	(
	cd hgrepo &&
	setup_repo hg sub_hg &&
	setup_repo git sub_git &&
	echo "sub_hg = sub_hg" > .hgsub &&
	echo "sub_git = [git]sub_git" >> .hgsub &&
	hg add .hgsub &&
	hg commit -m substate
	)

	git clone hg::hgrepo gitrepo &&

	(
	cd gitrepo &&
	git-hg-helper sub update --force &&

		(
		cd sub_hg &&
		echo one > content_sub_hg &&
		git add content_sub_hg &&
		git commit -m one_sub_hg &&
		# detached HEAD
		git push origin HEAD:master &&
		# also fetch to ensure notes are updated
		git fetch origin
		) &&

		(
		cd sub_git &&
		echo one > content_sub_git &&
		git add content_sub_git &&
		git commit -m one_sub_git &&
		# detached HEAD; push revision to other side ... anywhere
		git push origin HEAD:refs/heads/new
		)
	) &&

	(
	cd gitrepo &&
	git-hg-helper sub upstate &&
	git diff &&
	git status --porcelain | grep .hgsubstate &&
	git add .hgsubstate &&
	git commit -m update_sub &&
	git push origin master
	) &&

	hg clone hgrepo hgclone &&

	(
	cd hgclone &&
	hg update
	) &&

	check_branch hgclone default update_sub &&
	check_branch hgclone/sub_hg default one_sub_hg &&
	check hgclone/sub_git HEAD one_sub_git
'

test_expect_success 'subcommand sub status' '
	test_when_finished "rm -rf gitrepo* hgrepo*" &&

	setup_repo hg hgrepo &&
	(
	cd hgrepo &&
	setup_repo hg sub_hg_a &&
	setup_repo hg sub_hg_b &&
	setup_repo git sub_git &&
	echo "sub_hg_a = sub_hg_a" > .hgsub &&
	echo "sub_hg_b = sub_hg_b" >> .hgsub &&
	echo "sub_git = [git]sub_git" >> .hgsub &&
	hg add .hgsub &&
	hg commit -m substate
	)

	git clone hg::hgrepo gitrepo &&

	(
	cd gitrepo &&
	git-hg-helper sub update --force sub_hg_a  &&
	git-hg-helper sub update --force sub_git &&
		(
		# advance and add a tag to the git repo
		cd sub_git &&
		echo one > content_sub_git &&
		git add content_sub_git &&
		git commit -m one_sub_git &&
		git tag feature-a
		) &&

	git-hg-helper sub status --cached > output &&
	cat output &&
	grep "^ .*sub_hg_a (.*master.*)$" output &&
	grep "^-.*sub_hg_b$" output &&
	grep "^+.*sub_git (feature-a~1)$" output &&
	git-hg-helper sub status sub_git > output &&
	cat output &&
	grep "^+.*sub_git (feature-a)$" output > actual &&
	test_cmp output actual
	)
'

test_done
