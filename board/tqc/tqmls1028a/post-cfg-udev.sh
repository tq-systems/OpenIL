#!/usr/bin/env bash

main()
{
	cp board/tqc/tqmls1028a/ls1028-10-network.rules ${TARGET_DIR}/etc/udev/rules.d/10-network.rules

	exit $?
}

main $@
