#!/usr/bin/env bash
# args from BR2_ROOTFS_POST_SCRIPT_ARGS
# $2 linux building directory
# $3 buildroot top directory
# $4 u-boot building directory

main()
{
	echo ${2}
	echo ${3}
	echo ${4}
	echo ${BR2_ROOTFS_PARTITION_SIZE}

	# build the SDcard image
	local FILES=""ls1028a-mbls1028a.dtb", "Image.gz", "ls1028a-dp-fw.bin""
	local GENIMAGE_CFG="$(mktemp --suffix genimage.cfg)"
	local GENIMAGE_TMP="${BUILD_DIR}/genimage.tmp"

	sed -e "s/%FILES%/${FILES}/" -e "s/%PARTITION_SIZE%/${BR2_ROOTFS_PARTITION_SIZE}/" \
		board/tqc/tqmls1028a/genimage.cfg.template > ${GENIMAGE_CFG}

	rm -rf "${GENIMAGE_TMP}"

	genimage \
		--rootpath "${TARGET_DIR}" \
		--tmppath "${GENIMAGE_TMP}" \
		--inputpath "${BINARIES_DIR}" \
		--outputpath "${BINARIES_DIR}" \
		--config "${GENIMAGE_CFG}"

	rm -f ${GENIMAGE_CFG}


	exit $?
}

main $@
