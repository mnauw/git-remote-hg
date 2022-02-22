prefix := $(HOME)

bindir := $(prefix)/bin
mandir := $(prefix)/share/man/man1

all: build doc

build:
	if [ -n "$$PYTHON" ] && "$$PYTHON" -c 'import mercurial' 2> /dev/null ; then \
		: Use chosen Python version ; \
	elif python3 -c 'import mercurial' 2> /dev/null ; then \
		PYTHON=python3 ; \
	elif python2 -c 'import mercurial' 2> /dev/null ; then \
		PYTHON=python2 ; \
	elif python -c 'import mercurial' 2> /dev/null ; then \
		PYTHON=python ; \
	else \
		echo 'Python with Mercurial not available' >&2 ; \
		exit 1 ; \
	fi ; \
	mkdir -p bin ; \
	for s in git-remote-hg git-hg-helper ; do \
		printf "%s\n" "#!/usr/bin/env $$PYTHON" > "bin/$$s" ; \
		tail -n +2 "./$$s" >> "bin/$$s" ; \
		chmod 755 "bin/$$s" ; \
		touch -r "./$$s" "bin/$$s" ; \
	done

doc: doc/git-remote-hg.1

test:
	$(MAKE) -C test

doc/git-remote-hg.1: doc/git-remote-hg.txt
	a2x -d manpage -f manpage $<

clean:
	$(RM) doc/git-remote-hg.1
	$(RM) -r bin/

D = $(DESTDIR)

install: build
	install -d -m 755 $(D)$(bindir)/
	install -m 755 bin/git-remote-hg $(D)$(bindir)/git-remote-hg
	install -m 755 bin/git-hg-helper $(D)$(bindir)/git-hg-helper

install-doc: doc
	install -d -m 755 $(D)$(mandir)/
	install -m 644 doc/git-remote-hg.1 $(D)$(mandir)/git-remote-hg.1

pypi:
	version=`git describe --tags ${REV}` && \
		sed -i "s/version = .*/version = '$$version'[1:]/" setup.py
	-rm -rf dist build
	python setup.py sdist bdist_wheel

pypi-upload:
	twine upload dist/*

pypi-test:
	twine upload --repository-url https://test.pypi.org/legacy/ dist/*

.PHONY: all build test install install-doc clean pypy pypy-upload
