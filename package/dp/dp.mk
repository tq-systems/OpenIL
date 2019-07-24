################################################################################
#
# DP firmware for NXP layerscape platforms
#
################################################################################

DP_SITE = https://www.nxp.com/lgfiles/sdk/ls1028a_bsp_01
DP_SOURCE = ls1028a-dp-fw.bin
DP_BIN = $(call qstrip,$(BR2_PACKAGE_DP_BIN))

define DP_EXTRACT_CMDS
	cp $(BR2_DL_DIR)/$(DP_SOURCE) $(@D)/ &&\
	cd $(@D)/ && \
	chmod +x $(DP_SOURCE) && ./$(DP_SOURCE) --auto-accept;
endef

define DP_BUILD_CMDS
	cd $(@D)/ && \
	cp -f ls1028a-dp-fw/cadence/$(DP_BIN) $(BINARIES_DIR)/ls1028a-dp-fw.bin;
endef

$(eval $(generic-package))
