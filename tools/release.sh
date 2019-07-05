#!/bin/bash
#
# File:        release.sh
# Copyright (C) 2014 - 2019 TQ Systems GmbH
# @author Michael Krummsdorf <michael.krummsdorf@tq-group.com>
#
# Description: A utility script that builds an packages the BSP.
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

readonly PROGRAM="$(basename ${0})"
readonly SCRIPT_LIBDIR="$(dirname ${0})"

# needed for do_query_release_type
PLATFORM_RELEASE_STAMP=
PLATFORM_VERSION_PART=
PLATFORM_PLATFORM_PART=

source "${SCRIPT_LIBDIR}/tools_lib_git.sh"

readonly TARBALLDIR=sources
readonly DEVPKGDIR=devpkg
readonly DOCUMENTATIONDIR=Documentation/latex

# RETURN VALUES/EXIT STATUS CODES
readonly E_BAD_OPTION=254
readonly E_UNKNOWN=255

function usage () {
    echo "Usage is as follows:"
    echo
    echo "$PROGRAM <--usage|--help|-?>"
    echo "    Prints this usage output and exits."
    echo "$PROGRAM [--platform <name>] [--stamp <name>] [--use-git] [--debug] [--license]"
    echo "    compile everything and create archives if under git."
    echo " --platform <name>"
    echo "     assign platform name from config stage: make <platform>_defconfig"
    echo " --stamp <name>"
    echo "    compile everything and create archives from <stamp> if under git."
    echo "--use-git"
    echo "    use git for patching instead of quilt (needed for binary patches)."
    echo "--license"
    echo "    extract license info."
    echo "--debug"
    echo "    omit cleaning before collecting data."
    echo
}

#
# $1: base directory
# $2: [optional] git release name
# return 0 on success
#
function extract_license_info () {
	local MYPWD=${1}
	local ret="42"

	if [ -z ${2} ]; then
		${MYPWD}/tools/license.sh
		ret=$?
	else
		${MYPWD}/tools/license.sh --stamp ${2}
		ret=$?
	fi

	if [ "${ret}" -ne "0" ]; then
		echo "license extraction failed, see log.";
		return $E_UNKNOWN;
	fi

	return 0
}

#
# $1: exact ptxdist call
# $2: tarball export dir
# $3: not zero if ptxdist is able to print internal vars
# return 0 on success
#
function export_src_packages () {
	local PTX_PTXDIST=$1
	local THE_TARBALLDIR=$2
	local PTX_CAN_PRINT=$3

	mkdir -p ${THE_TARBALLDIR}
	[ "$?" -ne "0" ] && echo "error: creating ${THE_TARBALLDIR}" && return $E_UNKNOWN

	for p in $(make external-deps); do
		cp -v dl/${p} ${THE_TARBALLDIR} && echo ${p} >> ${THE_TARBALLDIR}/source.list
		if [ $? -ne 0 ]; then
			echo "source package export failed, see log.";
			return $E_UNKNOWN;
		fi
	done

	if [ "${PTX_CAN_PRINT}" -ne "0" ]; then
		${PTX_PTXDIST} print PACKAGES-y >> ${THE_TARBALLDIR}/source.list
		if [ $? -ne 0 ]; then
			echo "package list export failed, see log.";
			return $E_UNKNOWN;
		fi

		${PTX_PTXDIST} print HOST_PACKAGES-y >> ${THE_TARBALLDIR}/source.list
		if [ $? -ne 0 ]; then
			echo "host package list export failed, see log.";
			exit $E_UNKNOWN;
		fi

		${PTX_PTXDIST} print CROSS_PACKAGES-y >> ${THE_TARBALLDIR}/source.list
		if [ $? -ne 0 ]; then
			echo "cross package list export failed, see log.";
			exit $E_UNKNOWN;
		fi
	fi

	return 0
}

function main () {
	local PATCH_OPT=
	local MYPWD=
	local DO_DEBUG="no"
	local HAVE_GIT="0"
	local EXTRACT_LICENSES="0"
	local ret=0
	local PTXDIST_CAN_PRINT="0"
	local CONFIG_FILE_VERSION=""
	local PLATFORM_FILE_VERSION=""
	local PLATFORM
	local PLATFORM_NAME
	local PTXDIST="echo"
	local LOGFILE

	# Process command-line arguments.
	while test $# -gt 0; do
	    case $1 in
		--platform )
		    shift
		    PLATFORM_NAME="$1"
		    shift
		    ;;

		--stamp )
		    shift
		    STAMP="$1"
		    shift
		    ;;

		--use-git )
		    shift
		    PATCH_OPT="--git"
		    ;;

		--license )
		    shift
		    EXTRACT_LICENSES="1"
		    ;;

		--debug )
		    shift
		    DO_DEBUG="yes"
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

	STAMPFILE=${PLATFORM_NAME}-stamp
	MYPWD=$(pwd)
	PLATFORM=output
	LOGFILE=${PLATFORM}/make.log

	[ check_git ] && HAVE_GIT="1"

	do_query_release_type "noversion" ${PLATFORM} ${STAMP}
	[ "${?}" -ne "0" ] && return ${E_UNKNOWN}

	readonly PLATFORM_PKG_SRC_ARCHIVE=${PLATFORM}/dist/${PLATFORM_PLATFORM_PART}.Packages.SRC.${PLATFORM_VERSION_PART}.tar.gz
	readonly PLATFORM_PKG_BIN_ARCHIVE=${PLATFORM}/dist/${PLATFORM_PLATFORM_PART}.Packages.BIN.${PLATFORM_VERSION_PART}.tar.gz
	readonly PLATFORM_BSP_SRC_NAME=${PLATFORM_PLATFORM_PART}.SRC.${PLATFORM_VERSION_PART}
	readonly PLATFORM_BSP_SRC_ARCHIVE=${PLATFORM}/dist/${PLATFORM_PLATFORM_PART}.SRC.${PLATFORM_VERSION_PART}.tar
	readonly PLATFORM_BSP_BIN_ARCHIVE=${PLATFORM}/dist/${PLATFORM_PLATFORM_PART}.BIN.${PLATFORM_VERSION_PART}.tar.gz
	readonly PLATFORM_BSP_MD5FILE=${PLATFORM_PLATFORM_PART}.md5sum.${PLATFORM_VERSION_PART}
	readonly PLATFORM_LIC_ARCHIVE=${PLATFORM}/dist/${PLATFORM_PLATFORM_PART}.LIC.${PLATFORM_VERSION_PART}.tar.gz

	# clean previous build if needed
	rm -f ${PLATFORM}/images/${STAMPFILE}
	rm -f ${PLATFORM}/dist/${PLATFORM_BSP_MD5FILE}

	if [ "${DO_DEBUG}" != "yes" ]; then
		echo "DO_DEBUG: ${DO_DEBUG}"
		rm ${LOGFILE}
		make clean
	fi

	if [ "${HAVE_GIT}" -ne "0" ]; then
		git log -1 > ${PLATFORM}/images/${STAMPFILE}
	fi

	make all | tee -a ${LOGFILE}
	ret=$?
	if [ $ret -ne 0 ]; then
		echo "build error, see log.";
		exit $E_UNKNOWN;
	fi

	if [ "${EXTRACT_LICENSES}" -ne "0" ]; then
		make legal-info | tee -a ${LOGFILE} && \
		tar -cvzf ${PLATFORM_LIC_ARCHIVE} -C ${PLATFORM} legal-info
		if [ "$?" -ne "0" ]; then
			echo "license extraction failed, see log.";
			exit $E_UNKNOWN;
		fi
	fi

	export_src_packages ${PTXDIST} ${PLATFORM}/${TARBALLDIR} ${PTXDIST_CAN_PRINT}
	[ "$?" -ne "0" ] && exit $E_UNKNOWN

	mkdir -p ${PLATFORM}/dist
	! [ -d ${PLATFORM}/dist ] && echo "dist dir creation failed, see log." && exit $E_UNKNOWN;

	tar -cvzf ${PLATFORM_PKG_SRC_ARCHIVE} -C ${PLATFORM} ${TARBALLDIR}
	ret=$?
	if [ $ret -ne 0 ]; then
		echo "${TARBALLDIR} archiving failed, see log.";
		exit $E_UNKNOWN;
	fi

	${MYPWD}/tools/collect_hashes.sh --directory ${PLATFORM}/images > ${PLATFORM}/dist/${PLATFORM_BSP_MD5FILE}
	ret=$?
	if [ $ret -ne 0 ]; then
		echo "image hashing failed.";
		exit $E_UNKNOWN;
	fi

	cp ${PLATFORM}/dist/${PLATFORM_BSP_MD5FILE} ${PLATFORM}/images
	tar -cvzf ${PLATFORM_BSP_BIN_ARCHIVE} -C ${PLATFORM}/images .
	ret=$?
	if [ $ret -ne 0 ]; then
		echo "image archiving failed, see log.";
		exit $E_UNKNOWN;
	fi


	if [ "${HAVE_GIT}" -ne "0" ]; then
		echo "create archive ${PLATFORM_BSP_SRC_ARCHIVE} from ${RELEASE_STAMP} ...";
		$MYPWD/tools/git-archive-all.sh --format tar.gz --prefix ${PLATFORM_BSP_SRC_NAME}/ --commit ${RELEASE_STAMP} ${MYPWD}/${PLATFORM_BSP_SRC_ARCHIVE};
		ret=$?
		if [ $ret -ne 0 ]; then
			echo "git archiving failed, see log.";
			exit $E_UNKNOWN;
		fi
	fi

	exit 0
}

main $@

