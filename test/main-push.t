CAPABILITY_PUSH=t

test -n "$TEST_DIRECTORY" || TEST_DIRECTORY=$(dirname $0)/
. "$TEST_DIRECTORY"/main.t


# .. and some push mode only specific tests

test_expect_success 'remote delete bookmark' '
	test_when_finished "rm -rf hgrepo* gitrepo*" &&

	(
	hg init hgrepo &&
	cd hgrepo &&
	echo zero > content &&
	hg add content &&
	hg commit -m zero
	hg bookmark feature-a
	) &&

	git clone "hg::hgrepo" gitrepo &&
	check_bookmark hgrepo feature-a zero &&

	(
	cd gitrepo &&
	git push --quiet origin :feature-a
	) &&

	check_bookmark hgrepo feature-a ''
'

test_expect_success 'source:dest bookmark' '
	test_when_finished "rm -rf hgrepo gitrepo" &&

	(
	hg init hgrepo &&
	cd hgrepo &&
	echo zero > content &&
	hg add content &&
	hg commit -m zero
	) &&

	git clone "hg::hgrepo" gitrepo &&

	(
	cd gitrepo &&
	echo one > content &&
	git commit -a -m one &&
	git push --quiet origin master:feature-b &&
	git push --quiet origin master^:refs/heads/feature-a
	) &&

	check_bookmark hgrepo feature-a zero &&
	check_bookmark hgrepo feature-b one &&

	(
	cd gitrepo &&
	git push --quiet origin master:feature-a
	) &&

	check_bookmark hgrepo feature-a one
'

setup_check_hg_commits_repo () {
        (
	rm -rf hgrepo* &&
	hg init hgrepo &&
	cd hgrepo &&
	echo zero > content &&
	hg add content &&
	hg commit -m zero
	) &&

	git clone "hg::hgrepo" gitrepo &&
	hg clone hgrepo hgrepo.second &&

	(
	cd gitrepo &&
	git remote add second hg::../hgrepo.second &&
	git fetch second
	) &&

	(
	cd hgrepo &&
	echo one > content &&
	hg commit -m one &&
	echo two > content &&
	hg commit -m two &&
	echo three > content &&
	hg commit -m three &&
	hg move content content-move &&
	hg commit -m moved &&
	hg move content-move content &&
	hg commit -m restored
        )
}

# a shared bag would make all of the following pretty trivial
git config --global remote-hg.shared-marks false

git config --global remote-hg.check-hg-commits fail
test_expect_success 'check-hg-commits with fail mode' '
	test_when_finished "rm -rf gitrepo* hgrepo*" &&

	setup_check_hg_commits_repo &&

	(
	cd gitrepo &&
	git fetch origin &&
	git reset --hard origin/master &&
	! git push second master 2>../error
	)

	cat error &&
	grep rejected error | grep hg
'

git config --global remote-hg.check-hg-commits push
# codepath for push is slightly different depending on shared proxy involved
# so tweak to test both
check_hg_commits_push () {
	test_when_finished "rm -rf gitrepo* hgrepo*" &&

	setup_check_hg_commits_repo &&

	(
	cd gitrepo &&
	git fetch origin &&
	git reset --hard origin/master &&
	git push second master 2> ../error
	) &&

	cat error &&
	grep "hg changeset" error &&

	hg log -R hgrepo > expected &&
	hg log -R hgrepo.second | grep -v bookmark > actual &&
	test_cmp expected actual
}

unset GIT_REMOTE_HG_TEST_REMOTE
test_expect_success 'check-hg-commits with push mode - no local proxy' '
	check_hg_commits_push
'

GIT_REMOTE_HG_TEST_REMOTE=1 &&
export GIT_REMOTE_HG_TEST_REMOTE
test_expect_success 'check-hg-commits with push mode - with local proxy' '
	check_hg_commits_push
'

setup_check_shared_marks_repo () {
        (
	rm -rf hgrepo* &&
	hg init hgrepo &&
	cd hgrepo &&
	echo zero > content &&
	hg add content &&
	hg commit -m zero
	) &&

	git clone "hg::hgrepo" gitrepo &&

	(
	cd gitrepo &&
	git remote add second hg::../hgrepo &&
	git fetch second
	)
}

check_marks () {
	dir=$1

	ls -al $dir &&
	if test "$2" = "y"
	then
		test -f $dir/marks-git && test -f $dir/marks-hg
	else
		test ! -f $dir/marks-git && test ! -f $dir/marks-hg
	fi
}

# cleanup setting
git config --global --unset remote-hg.shared-marks

test_expect_success 'shared-marks unset' '
	test_when_finished "rm -rf gitrepo* hgrepo*" &&

	setup_check_shared_marks_repo &&

	(
	cd gitrepo &&
	check_marks .git/hg y &&
	check_marks .git/hg/origin n &&
	check_marks .git/hg/second n
	)
'

test_expect_success 'shared-marks set to unset' '
	test_when_finished "rm -rf gitrepo* hgrepo*" &&

	git config --global remote-hg.shared-marks true &&
	setup_check_shared_marks_repo &&

	(
	cd gitrepo &&
	check_marks .git/hg y &&
	check_marks .git/hg/origin n &&
	check_marks .git/hg/second n
	) &&

	git config --global remote-hg.shared-marks false &&
	(
		cd gitrepo &&
		git fetch origin &&
		check_marks .git/hg n &&
		check_marks .git/hg/origin y &&
		check_marks .git/hg/second y
	)
'

test_expect_success 'shared-marks unset to set' '
	test_when_finished "rm -rf gitrepo* hgrepo*" &&

	git config --global remote-hg.shared-marks false &&
	setup_check_shared_marks_repo &&

	(
	cd gitrepo &&
	check_marks .git/hg n &&
	check_marks .git/hg/origin y &&
	check_marks .git/hg/second y
	) &&

	git config --global --unset remote-hg.shared-marks &&
	(
		cd gitrepo &&
		git fetch origin &&
		check_marks .git/hg n &&
		check_marks .git/hg/origin y &&
		check_marks .git/hg/second y
	) &&

	git config --global remote-hg.shared-marks true &&
	(
		cd gitrepo &&
		git fetch origin &&
		check_marks .git/hg y &&
		check_marks .git/hg/origin n &&
		check_marks .git/hg/second n
	)
'

test_expect_success 'push with renamed executable preserves executable bit' '
	test_when_finished "rm -rf hgrepo gitrepo*" &&

	hg init hgrepo &&

	(
	git init gitrepo &&
	cd gitrepo &&
	git remote add origin "hg::../hgrepo" &&
	echo one > content &&
	chmod a+x content &&
	git add content &&
	git commit -a -m one &&
	git mv content content2 &&
	git commit -a -m two &&
	git push origin master
	) &&

	(
	umask 0 &&
	cd hgrepo &&
	hg update &&
	stat content2 >expected &&
	grep -- -r.xr.xr.x expected
	)
'

test_expect_success 'push with submodule' '
	test_when_finished "rm -rf sub hgrepo gitrepo*" &&

	hg init hgrepo &&

	(
	git init sub &&
	cd sub &&
	: >empty &&
	git add empty &&
	git commit -m init
	) &&

	(
	git init gitrepo &&
	cd gitrepo &&
	git submodule add ../sub sub &&
	git remote add origin "hg::../hgrepo" &&
	git commit -a -m sub &&
	git push origin master
	) &&

	(
	cd hgrepo &&
	hg update &&
	expected="[git-remote-hg: skipped import of submodule at $(git -C ../sub rev-parse HEAD)]"
	test "$expected" = "$(cat sub)"
	)
'

# cleanup setting
git config --global --unset remote-hg.shared-marks

test_done
