################################################################################
#
# xenomai
#
################################################################################

XENOMAI_VERSION = $(call qstrip,$(BR2_PACKAGE_XENOMAI_VERSION))
ifeq ($(XENOMAI_VERSION),)
XENOMAI_VERSION = OpenIL-Xenomai-201805
else
BR_NO_CHECK_HASH_FOR += $(XENOMAI_SOURCE)
endif

XENOMAI_SITE = https://github.com/openil/xenomai-3.git
XENOMAI_LICENSE = GPLv2+ with exception (headers), LGPLv2.1+ (libraries), GPLv2+ (kernel), GFDLv1.2+ (docs), GPLv2 (ipipe patch, can driver)
# GFDL is not included but refers to gnu.org
XENOMAI_SITE_METHOD = git
XENOMAI_LICENSE_FILES = debian/copyright include/COPYING
XENOMAI_INSTALL_STAGING = YES
XENOMAI_INSTALL_TARGET_OPTS = DESTDIR=$(TARGET_DIR) install-user
XENOMAI_INSTALL_STAGING_OPTS = DESTDIR=$(STAGING_DIR) install-user

XENOMAI_CONF_OPTS += --includedir=/usr/include/xenomai/ --disable-doc-install --with-core=cobalt --enable-smp --enable-pshared --enable-tls --enable-lores-clock --enable-dlopen-libs --enable-clock-monotonic-raw 

define XENOMAI_REMOVE_DEVFILES
	for i in xeno-config xeno-info wrap-link.sh ; do \
		rm -f $(TARGET_DIR)/usr/bin/$$i ; \
	done
endef

define XENOMAI_CREATE_MISSING_FILES
	cd $(@D)/ && \
	sed '92im4_pattern_allow([LT_SYS_SYMBOL_USCORE])' configure.ac > configure.ac.patched && \
	mv configure.ac.patched configure.ac && \
	cd $(@D)/ && $(TARGET_MAKE_ENV) ./scripts/bootstrap
endef
XENOMAI_POST_EXTRACT_HOOKS += XENOMAI_CREATE_MISSING_FILES

XENOMAI_POST_INSTALL_TARGET_HOOKS += XENOMAI_REMOVE_DEVFILES

ifeq ($(BR2_PACKAGE_XENOMAI_TESTSUITE),)
define XENOMAI_REMOVE_TESTSUITE
	rm -rf $(TARGET_DIR)/usr/share/xenomai/
	for i in klatency rtdm xeno xeno-load check-vdso \
		irqloop cond-torture-posix switchtest arith \
		sigtest clocktest cyclictest latency wakeup-time \
		xeno-test cond-torture-native mutex-torture-posix \
		mutex-torture-native ; do \
		rm -f $(TARGET_DIR)/usr/bin/$$i ; \
	done
endef

XENOMAI_POST_INSTALL_TARGET_HOOKS += XENOMAI_REMOVE_TESTSUITE
endif

ifeq ($(BR2_PACKAGE_XENOMAI_RTCAN),)
define XENOMAI_REMOVE_RTCAN_PROGS
	for i in rtcanrecv rtcansend ; do \
		rm -f $(TARGET_DIR)/usr/bin/$$i ; \
	done
	rm -f $(TARGET_DIR)/usr/sbin/rtcanconfig
endef

XENOMAI_POST_INSTALL_TARGET_HOOKS += XENOMAI_REMOVE_RTCAN_PROGS
endif

ifeq ($(BR2_PACKAGE_XENOMAI_ANALOGY),)
define XENOMAI_REMOVE_ANALOGY
	for i in cmd_bits cmd_read cmd_write insn_write \
		insn_bits insn_read ; do \
		rm -f $(TARGET_DIR)/usr/bin/$$i ; \
	done
	rm -f $(TARGET_DIR)/usr/sbin/analogy_config
	rm -f $(TARGET_DIR)/usr/lib/libanalogy.*
endef

XENOMAI_POST_INSTALL_TARGET_HOOKS += XENOMAI_REMOVE_ANALOGY
endif

XENOMAI_REMOVE_SKIN_LIST += $(if $(BR2_PACKAGE_XENOMAI_NATIVE_SKIN),,native)
XENOMAI_REMOVE_SKIN_LIST += $(if $(BR2_PACKAGE_XENOMAI_POSIX_SKIN),,posix)
XENOMAI_REMOVE_SKIN_LIST += $(if $(BR2_PACKAGE_XENOMAI_VXWORKS_SKIN),,vxworks)
XENOMAI_REMOVE_SKIN_LIST += $(if $(BR2_PACKAGE_XENOMAI_PSOS_SKIN),,psos)
XENOMAI_REMOVE_SKIN_LIST += $(if $(BR2_PACKAGE_XENOMAI_RTAI_SKIN),,rtai)
XENOMAI_REMOVE_SKIN_LIST += $(if $(BR2_PACKAGE_XENOMAI_UITRON_SKIN),,uitron)
XENOMAI_REMOVE_SKIN_LIST += $(if $(BR2_PACKAGE_XENOMAI_VRTX_SKIN),,vrtx)

define XENOMAI_REMOVE_SKINS
	for i in $(XENOMAI_REMOVE_SKIN_LIST) ; do \
		rm -f $(TARGET_DIR)/usr/lib/lib$$i.* ; \
		if [ $$i == "posix" ] ; then \
			rm -f $(TARGET_DIR)/usr/lib/posix.wrappers ; \
		fi ; \
	done
endef

XENOMAI_POST_INSTALL_TARGET_HOOKS += XENOMAI_REMOVE_SKINS

define XENOMAI_DEVICES
/dev/rtheap  c  666  0  0  10  254  0  0  -
/dev/rtscope c  666  0  0  10  253  0  0  -
/dev/rtp     c  666  0  0  150 0    0  1  32
endef

ifeq ($(BR2_PACKAGE_HAS_UDEV),y)
XENOMAI_DEPENDENCIES += udev

define XENOMAI_INSTALL_UDEV_RULES
	if test -d $(TARGET_DIR)/etc/udev/rules.d ; then \
		for f in $(@D)/kernel/cobalt/udev/*.rules ; do \
			cp $$f $(TARGET_DIR)/etc/udev/rules.d/ || exit 1 ; \
		done ; \
	fi;
endef

XENOMAI_POST_INSTALL_TARGET_HOOKS += XENOMAI_INSTALL_UDEV_RULES
endif # udev

$(eval $(autotools-package))
