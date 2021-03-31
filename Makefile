prefix := $(HOME)

bindir := $(prefix)/bin
mandir := $(prefix)/share/man/man1

all: doc

doc: doc/git-remote-hg.1

test:
	$(MAKE) -C test

doc/git-remote-hg.1: doc/git-remote-hg.txt
	a2x -d manpage -f manpage $<

clean:
	$(RM) doc/git-remote-hg.1

D = $(DESTDIR)

install:
	install -d -m 755 $(D)$(bindir)/
	install -m 755 git-remote-hg $(D)$(bindir)/git-remote-hg
	install -m 755 git-hg-helper $(D)$(bindir)/git-hg-helper

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

.PHONY: all test install install-doc clean pypy pypy-upload
