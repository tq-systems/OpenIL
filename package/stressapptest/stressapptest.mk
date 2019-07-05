################################################################################
#
# stress app test
#
################################################################################
STRESSAPPTEST_VERSION = v1.0.9
STRESSAPPTEST_SITE = https://github.com/stressapptest/stressapptest
STRESSAPPTEST_SITE_METHOD = git

define STRESSAPPTEST_CONFIGURE_CMDS
	(cd $(@D); \
	$(TARGET_CONFIGURE_OPTS) \
	$(TARGET_CONFIGURE_ARGS) \
	 ./configure \
	 --prefix=/usr \
	 --host=$(BR2_TOOLCHAIN_EXTERNAL_PREFIX) \
	)
endef

define STRESSAPPTEST_BUILD_CMDS
	$(TARGET_CONFIGURE_OPTS) $(MAKE) -C $(@D)
endef

define STRESSAPPTEST_INSTALL_TARGET_CMDS
	$(INSTALL) -m 0755 $(@D)/src/stressapptest $(TARGET_DIR)/usr/bin
endef

$(eval $(generic-package))
