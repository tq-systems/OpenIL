#!/bin/bash
#
# File:        collect_hashes.sh
# Copyright (C) 2016 TQ Systems GmbH
# @author Markus Niebel <Markus.Niebel@tq-group.com>
#
# Description: A utility script to collect hashes for files in a directory.
#
#              Use release.sh to perform a complete build and create archives of
#              images, source tarballs, dev packages and BSP
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
# set -e 
set -C # noclobber

# RETURN VALUES/EXIT STATUS CODES
readonly E_BAD_OPTION=254
readonly E_UNKNOWN=255

function usage () {
    echo "Usage is as follows:"
    echo
    echo "$PROGRAM <--usage|--help|-?>"
    echo "    Prints this usage output and exits."
    echo "$PROGRAM"
    echo "    print md5sum for all files in current dir"
    echo "$PROGRAM --directory <dir>"
    echo "    printout md5sums for all files in <dir>."
    echo
}


function main () {
	MYPWD=$(pwd)
	DIRECTORY=$(pwd)

	# Process command-line arguments.
	while test $# -gt 0; do
	    case ${1} in

		--directory )
		    shift
		    DIRECTORY="${1}"
		    ;;

		-? | --usage | --help )
		    usage
		    exit 0
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

	if [ -d ${DIRECTORY} ]; then
		cd ${DIRECTORY}
		FILES=$(find . -maxdepth 1 -type f)

		for file in ${FILES}; do
			md5sum ${file}
			if [ "$?" -ne "0" ]; then
				echo "ERROR: ${file}"
			fi
		done
	fi
	cd ${MYPWD}
}

main $@
