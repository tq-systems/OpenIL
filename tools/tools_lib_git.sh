#!/bin/bash
#
# File:        tools_lib_git.sh
# Copyright (C) 2017 - 2018 TQ Systems GmbH
# @author Markus Niebel <Markus.Niebel@tq-group.com>
#
# Description: helper fuctions for the BSP.
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

check_git() {
	echo "Checking for git ..."
	git --version >/dev/null 2>&1
	if [ "$?" -ne "0" ]; then
		echo "'git' not found! Please install." >&2
		exit 255;
	fi
	return 0
}

function do_query_release_type () {
	local VERSION=$1
	local PLATFORM=$2
	local GITSTAMP=$3
	local GIT_STAMP=
	local PLATFORM_DIST_DIR=$PLATFORM/dist
	local IS_GIT_TAG="0"

	if [ "${HAVE_GIT}" -ne "0" ]; then
		local GITHEAD=$(git rev-parse --verify --short HEAD 2>/dev/null)
		local GITATAG="$(git describe 2>/dev/null)"
		git show-ref --quiet --tags ${GITATAG} 2>/dev/null
		[ "${?}" -eq "0" ] && IS_GIT_TAG="1"

		if [ "${IS_GIT_TAG}" -gt "0" ]; then
			GIT_STAMP=${GITATAG};
		elif ! [ -z ${GITATAG} ]; then
			GIT_STAMP=$(echo "${GITATAG}" | awk -F- '{ for (i = 1; i <= NF - 2; i++) { if ($i == 1) print $i; else printf("-%s", $i) } }')
			GIT_STAMP+=$(echo "${GITATAG}" | awk -F- '{ if (NF >= 3) printf("-%05d-%s", $(NF-1),$(NF));}')
		else
			GIT_STAMP=git$(printf "%s%s" -g ${GITHEAD})
		fi

		RELEASE_STAMP=$(git log -1 --pretty=%H);
		if ! [ -z "${GITSTAMP}" ]; then
			GIT_STAMP=$(git log ${GITSTAMP} -1 --pretty=%H);
			if [ "${GIT_STAMP}" = "${RELEASE_STAMP}" ]; then
				RELEASE_STAMP=${GITSTAMP};
				PLATFORM_RELEASE_STAMP=${RELEASE_STAMP};
				echo "RELEASE: ${RELEASE_STAMP}";
			else
				echo "checked out version did not match ${GITSTAMP} ...";
				return E_UNKNOWN=255
			fi
		else
			PLATFORM_RELEASE_STAMP=$PLATFORM.${GIT_STAMP};
		fi
	else
		echo "no git, use BSP version ...";
		RELEASE_STAMP=${VERSION};
		PLATFORM_RELEASE_STAMP=$PLATFORM.$RELEASE_STAMP;
	fi

	PLATFORM_VERSION_PART=${PLATFORM_RELEASE_STAMP##*.}
	PLATFORM_PLATFORM_PART=${PLATFORM_RELEASE_STAMP%.*}

	return 0
}

