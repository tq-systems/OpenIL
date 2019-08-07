#!/bin/bash -
#
# File:        git-archive-all.sh
# Copyright (C) 2014 - 2016 TQ Systems GmbH
# @author Markus Niebel <Markus.Niebel@tq-group.com>
#
# Description: A utility script that builds an archive file(s) of all
#              git repositories and submodules in the current path.
#              Useful for creating a single tarfile of a git super-
#              project that contains other submodules.
#
# Examples:    Use git-archive-all.sh to create archive distributions
#              from git repositories. To use, simply do:
#
#                  cd $GIT_DIR; git-archive-all.sh
#
#              where $GIT_DIR is the root of your git superproject.
#
# License:     GPLv2
#
###############################################################################
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
#
###############################################################################

# DEBUGGING
### set -e
set -C # noclobber

# TRAP SIGNALS
trap 'cleanup' QUIT EXIT

# For security reasons, explicitly set the internal field separator
# to newline, space, tab
OLD_IFS=$IFS
IFS='
 	'

function cleanup () {
    rm -f $TMPFILE
    rm -f $TOARCHIVE
    IFS="$OLD_IFS"
}

function usage () {
    echo "Usage is as follows:"
    echo
    echo "$PROGRAM <--version>"
    echo "    Prints the program version number on a line by itself and exits."
    echo
    echo "$PROGRAM <--usage|--help|-?>"
    echo "    Prints this usage output and exits."
    echo
    echo "$PROGRAM [--format <fmt>] [--prefix <path>] [--verbose|-v] [--separate|-s] [output_file]"
    echo "    Creates an archive for the entire git superproject, and its submodules"
    echo "    using the passed parameters, described below."
    echo
    echo "    If '--format' is specified, the archive is created with the named"
    echo "    git archiver backend. Obviously, this must be a backend that git archive"
    echo "    understands. The format defaults to 'tar' if not specified."
    echo
    echo "    If '--prefix' is specified, the archive's superproject and all submodules"
    echo "    are created with the <path> prefix named. The default is to not use one."
    echo
    echo "    If '--separate' or '-s' is specified, individual archives will be created"
    echo "    for each of the superproject itself and its submodules. The default is to"
    echo "    concatenate individual archives into one larger archive."
    echo
    echo "    If '--commit' or '-c' is specified, use commit instead of HEAD"
    echo
    echo "    If 'output_file' is specified, the resulting archive is created as the"
    echo "    file named. This parameter is essentially a path that must be writeable."
    echo "    When combined with '--separate' ('-s') this path must refer to a directory."
    echo "    Without this parameter or when combined with '--separate' the resulting"
    echo "    archive(s) are named with a dot-separated path of the archived directory and"
    echo "    a file extension equal to their format (e.g., 'superdir.submodule1dir.tar')."
    echo
    echo "    If '--verbose' or '-v' is specified, progress will be printed."
}

function version () {
    echo "$PROGRAM version $VERSION"
}

# Internal variables and initializations.
readonly PROGRAM=`basename "$0"`
readonly VERSION=0.2

OLD_PWD="`pwd`"
TMPDIR=${TMPDIR:-/tmp}
TMPFILE=`mktemp "$TMPDIR/$PROGRAM.XXXXXX"` # Create a place to store our work's progress
TOARCHIVE=`mktemp "$TMPDIR/$PROGRAM.toarchive.XXXXXX"`
OUT_FILE=$OLD_PWD # assume "this directory" without a name change by default
SEPARATE=0
VERBOSE=0

TARCMD=tar
[[ $(uname) == "Darwin" ]] && TARCMD=gnutar
FORMAT=tar
PREFIX=
DO_TARGZ=0
TREEISH=HEAD
COMMIT=HEAD

# RETURN VALUES/EXIT STATUS CODES
readonly E_BAD_OPTION=254
readonly E_UNKNOWN=255

# Process command-line arguments.
while test $# -gt 0; do
    case $1 in
        --format )
            shift
            FORMAT="$1"
            shift
            ;;

        --prefix )
            shift
            PREFIX="$1"
            shift
            ;;

        --separate | -s )
            shift
            SEPARATE=1
            ;;

        --commit | -c )
            shift
            COMMIT="$1"
            shift
            ;;

        --version )
            version
            exit
            ;;

        --verbose | -v )
            shift
            VERBOSE=1
            ;;

        -? | --usage | --help )
            usage
            exit
            ;;

        -* )
            echo "Unrecognized option: $1" >&2
            usage
            exit $E_BAD_OPTION
            ;;

        * )
            break
            ;;
    esac
done

if [ "$FORMAT"=="tar.gz" ]; then
    echo "FORMAT = $FORMAT"
    DO_TARGZ=1
    FORMAT="tar"
else
    DO_TARGZ=0
fi

if [ ! -z "$1" ]; then
    OUT_FILE="$1"
    shift
fi

# Validate parameters; error early, error often.
if [ $SEPARATE -eq 1 -a ! -d $OUT_FILE ]; then
    echo "When creating multiple archives, your destination must be a directory."
    echo "If it's not, you risk being surprised when your files are overwritten."
    exit -1
elif [ `git config -l | grep -q '^core\.bare=false'; echo $?` -ne 0 ]; then
    echo "$PROGRAM must be run from a git working copy (i.e., not a bare repository)."
    exit -2
fi

if [ "$TREEISH" == "$COMMIT" ]; then
    echo "use HEAD ..."
else
    OLDBRANCH=$(git rev-parse --abbrev-ref HEAD);
    if [ "$OLDBRANCH" == "tmp_release_$COMMIT" ]; then
        HEAD_STAMP=$(git log -1 --pretty=%H);
        COMMIT_STAMP=$(git log $COMMIT -1 --pretty=%H);
        if [ "$HEAD_STAMP" != "$COMMIT_STAMP" ]; then
            echo -n "temp branch is currently in use but is not what should be archived, give up ...";
            exit -3;
        fi
        echo -n "use current branch HEAD ...";
    else
        echo "check for tmp_release_$COMMIT ..."
        git branch | grep "tmp_release_$COMMIT" > /dev/null;
        ret=$?
      echo "ret $ret ..."
        if [ $ret -eq 0 ]; then
            echo "tmp_release_$COMMIT exists ..."
            HEAD_STAMP=$(git log "tmp_release_$COMMIT" -1 --pretty=%H);
            COMMIT_STAMP=$(git log $COMMIT -1 --pretty=%H);
            if [ "$HEAD_STAMP" != "$COMMIT_STAMP" ]; then
                echo "temp branch exists but is not what should be archived, give up ...";
                git log "tmp_release_$COMMIT" -1 --pretty=%H;
                git log $COMMIT -1 --pretty=%H;
                exit -4;
            fi
            echo "try tmp_release_$COMMIT ..."
            git checkout "tmp_release_$COMMIT";
            echo -n "use existing branch tmp_release_$COMMIT ...";
        else
            echo -n "creating temporary branch ..."
            git checkout -b tmp_release_$COMMIT $COMMIT;
            git submodule init;
            git submodule sync;
            git submodule update --init --recursive;
        fi
    fi
    echo "done ..."
fi

# Create the superproject's git-archive
if [ $VERBOSE -eq 1 ]; then
    echo -n "creating superproject archive..."
fi
if [ -f $TMPDIR/$(basename "$(pwd)").$FORMAT ]; then
    rm $TMPDIR/$(basename "$(pwd)").$FORMAT
fi
git archive --format=$FORMAT --prefix="$PREFIX" $TREEISH > $TMPDIR/$(basename "$(pwd)").$FORMAT
if [ $VERBOSE -eq 1 ]; then
    echo "done"
fi
echo $TMPDIR/$(basename "$(pwd)").$FORMAT >| $TMPFILE # clobber on purpose
superfile=`head -n 1 $TMPFILE`

if [ $VERBOSE -eq 1 ]; then
    echo -n "looking for subprojects..."
fi
# find all '.git' dirs, these show us the remaining to-be-archived dirs
# we only want directories that are below the current directory
# find . -mindepth 2 -name '.git' -type d -print | sed -e 's/^\.\///' -e 's/\.git$//' >> $TOARCHIVE
# as of version 1.7.8, git places the submodule .git directories under the superprojects .git dir
# the submodules get a .git file that points to their .git dir. we need to find all of these too
# find . -mindepth 2 -name '.git' -type f -print | xargs grep -l "gitdir" | sed -e 's/^\.\///' -e 's/\.git$//' >> $TOARCHIVE
# git submodule foreach 'echo $path >> $TOARCHIVE'
rm $TOARCHIVE
grep path .gitmodules | sed 's/.*= //' > $TOARCHIVE

if [ $VERBOSE -eq 1 ]; then
    echo "done"
    echo "  found:"
    cat $TOARCHIVE | while read arch
    do
      echo "    $arch"
    done
fi

if [ $VERBOSE -eq 1 ]; then
    echo -n "archiving submodules..."
fi

TMPFILES=""

while read path; do
    TREEISH=$(git submodule | grep "^ .*${path%/} " | cut -d ' ' -f 2) # git submodule does not list trailing slashes in $path
    cd "$path"
    TESTNAME="$TMPDIR"/"$(echo "$path" | sed -e 's/\//./g')".$FORMAT
    if [ -f $TESTNAME ]; then
        rm $TESTNAME
    fi

    TMPFILES="$TMPFILES $TESTNAME "
    git archive --format=$FORMAT --prefix="${PREFIX}$path/" ${TREEISH:-HEAD} > "$TMPDIR"/"$(echo "$path" | sed -e 's/\//./g')".$FORMAT
    if [ $FORMAT == 'zip' ]; then
        # delete the empty directory entry; zipped submodules won't unzip if we don't do this
        zip -d "$(tail -n 1 $TMPFILE)" "${PREFIX}${path%/}" >/dev/null # remove trailing '/'
    fi
    echo "$TMPDIR"/"$(echo "$path" | sed -e 's/\//./g')".$FORMAT >> $TMPFILE
    cd "$OLD_PWD"
done < $TOARCHIVE
if [ $VERBOSE -eq 1 ]; then
    echo "done"
fi

if [ $VERBOSE -eq 1 ]; then
    echo -n "concatenating archives into single archive..."
fi
# Concatenate archives into a super-archive.
if [ $SEPARATE -eq 0 ]; then
    if [ $FORMAT == 'tar' ]; then
        sed -e '1d' $TMPFILE | while read file; do
            $TARCMD --concatenate -f "$superfile" "$file" && rm -f "$file"
        done
    elif [ $FORMAT == 'zip' ]; then
        sed -e '1d' $TMPFILE | while read file; do
            # zip incorrectly stores the full path, so cd and then grow
            cd `dirname "$file"`
            zip -g "$superfile" `basename "$file"` && rm -f "$file"
        done
        cd "$OLD_PWD"
    fi

    echo "$superfile" >| $TMPFILE # clobber on purpose
fi
if [ $VERBOSE -eq 1 ]; then
    echo "done"
fi

if [ $VERBOSE -eq 1 ]; then
    echo -n "moving archive $file to $OUT_FILE..."
fi

#
# TODO: SEPARATE=1 case not tested - should fail???
#
while read file; do
	mv "$file" "$OUT_FILE"
	if [ $DO_TARGZ -eq 1 ]; then
		gzip "$OUT_FILE";
	fi
done < $TMPFILE

if [ "x$OLDBRANCH" != "x" ]; then
    if [ $VERBOSE -eq 1 ]; then
        echo -n "try checkout $OLDBRANCH..."
    fi

    if [ "$OLDBRANCH" == "HEAD" ]; then
        git checkout -f $COMMIT
    else
        git checkout $OLDBRANCH
    fi
    if [ "$OLDBRANCH" != "tmp_release_$COMMIT" ]; then
        git branch -D tmp_release_$COMMIT
    fi
fi

if [ "x$TMPFILES" != "x" ]; then
	rm -f $TMPFILES;
	echo "erasing $TMPFILES";
fi

if [ $VERBOSE -eq 1 ]; then
    echo "done"
fi
