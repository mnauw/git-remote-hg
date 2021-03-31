# git-remote-hg setuptools script

import setuptools

# strip leading v
version = 'v1.0.2.1'[1:]

# check for released version
assert (len(version) > 0)
assert (version.find('-') < 0)

long_description = \
"""
'git-remote-hg' is a gitremote protocol helper for Mercurial.
It allows you to clone, fetch and push to and from Mercurial repositories as if
they were Git ones using a hg::some-url URL.

See the homepage for much more explanation.
"""

CLASSIFIERS = [
    "Programming Language :: Python",
    "Programming Language :: Python :: 2",
    "Programming Language :: Python :: 2.7",
    "Programming Language :: Python :: 3",
    "Programming Language :: Python :: 3.6",
    "License :: OSI Approved",
    "License :: OSI Approved :: GNU General Public License v2 (GPLv2)",
    "Development Status :: 5 - Production/Stable",
    "Intended Audience :: Developers",
]

setuptools.setup(name="git-remote-hg",
      version=version,
      author="Mark Nauwelaerts",
      author_email="mnauw@users.sourceforge.net",
      url="http://github.com/mnauw/git-remote-hg",
      description="access hg repositories as git remotes",
      long_description=long_description,
      license="GPLv2",
      keywords="git hg mercurial",
      scripts=["git-remote-hg", "git-hg-helper"],
      classifiers=CLASSIFIERS
     )

