#
# KERNEL
#
KERNEL_VER             = 3.14.28-1.8
KERNEL_TYPE            = vusolo4k
KERNEL_SRC_VER         = 3.14-1.8
KERNEL_SRC             = stblinux-${KERNEL_SRC_VER}.tar.bz2
KERNEL_URL             = http://archive.vuplus.com/download/kernel
ifeq ($(VUSOLO4K_MULTIBOOT), 1)
KERNEL_CONFIG          = $(KERNEL_TYPE)/defconfig_multi
else
KERNEL_CONFIG          = $(KERNEL_TYPE)/defconfig
endif
KERNEL_DIR             = $(BUILD_TMP)/linux

#
# Todo: findkerneldevice.py

DEPMOD = $(HOST_DIR)/bin/depmod

#
# Patches Kernel
#
COMMON_PATCHES_ARM = \

KERNEL_PATCHES = \
		armbox/$(KERNEL_TYPE)/bcm_genet_disable_warn.patch \
		armbox/$(KERNEL_TYPE)/linux_dvb-core.patch \
		armbox/$(KERNEL_TYPE)/rt2800usb_fix_warn_tx_status_timeout_to_dbg.patch \
		armbox/$(KERNEL_TYPE)/usb_core_hub_msleep.patch \
		armbox/$(KERNEL_TYPE)/rtl8712_fix_build_error.patch \
		armbox/$(KERNEL_TYPE)/0001-Support-TBS-USB-drivers.patch \
		armbox/$(KERNEL_TYPE)/0001-STV-Add-PLS-support.patch \
		armbox/$(KERNEL_TYPE)/0001-STV-Add-SNR-Signal-report-parameters.patch \
		armbox/$(KERNEL_TYPE)/0001-stv090x-optimized-TS-sync-control.patch \
		armbox/$(KERNEL_TYPE)/linux_dvb_adapter.patch \
		armbox/$(KERNEL_TYPE)/kernel-gcc6.patch \
		armbox/$(KERNEL_TYPE)/genksyms_fix_typeof_handling.patch \
		armbox/$(KERNEL_TYPE)/0001-tuners-tda18273-silicon-tuner-driver.patch \
		armbox/$(KERNEL_TYPE)/01-10-si2157-Silicon-Labs-Si2157-silicon-tuner-driver.patch \
		armbox/$(KERNEL_TYPE)/02-10-si2168-Silicon-Labs-Si2168-DVB-T-T2-C-demod-driver.patch \
		armbox/$(KERNEL_TYPE)/0003-cxusb-Geniatech-T230-support.patch \
		armbox/$(KERNEL_TYPE)/CONFIG_DVB_SP2.patch \
		armbox/$(KERNEL_TYPE)/dvbsky.patch \
		armbox/$(KERNEL_TYPE)/rtl2832u-2.patch

$(ARCHIVE)/$(KERNEL_SRC):
	$(DOWNLOAD) $(KERNEL_URL)/$(KERNEL_SRC)

$(D)/kernel.do_prepare: $(ARCHIVE)/$(KERNEL_SRC) $(PATCHES)/armbox/$(KERNEL_CONFIG)
	$(START_BUILD)
	rm -rf $(KERNEL_DIR)
	$(UNTAR)/$(KERNEL_SRC)
	set -e; cd $(KERNEL_DIR); \
		for i in $(KERNEL_PATCHES); do \
			echo -e "==> $(TERM_RED)Applying Patch:$(TERM_NORMAL) $$i"; \
			$(PATCH)/$$i; \
		done
	install -m 644 $(PATCHES)/armbox/$(KERNEL_CONFIG) $(KERNEL_DIR)/.config
ifeq ($(OPTIMIZATIONS), $(filter $(OPTIMIZATIONS), kerneldebug debug))
	@echo "Using kernel debug"
	@grep -v "CONFIG_PRINTK" "$(KERNEL_DIR)/.config" > $(KERNEL_DIR)/.config.tmp
	cp $(KERNEL_DIR)/.config.tmp $(KERNEL_DIR)/.config
	@echo "CONFIG_PRINTK=y" >> $(KERNEL_DIR)/.config
	@echo "CONFIG_PRINTK_TIME=y" >> $(KERNEL_DIR)/.config
endif
	@touch $@

$(D)/kernel.do_compile: $(D)/kernel.do_prepare
	set -e; cd $(KERNEL_DIR); \
		$(MAKE) -C $(KERNEL_DIR) ARCH=arm oldconfig
		$(MAKE) -C $(KERNEL_DIR) ARCH=arm CROSS_COMPILE=$(TARGET)- zImage modules
		$(MAKE) -C $(KERNEL_DIR) ARCH=arm CROSS_COMPILE=$(TARGET)- DEPMOD=$(DEPMOD) INSTALL_MOD_PATH=$(TARGET_DIR) modules_install
	@touch $@

KERNEL = $(D)/kernel
$(D)/kernel: $(D)/bootstrap $(D)/kernel.do_compile
	install -m 644 $(KERNEL_DIR)/vmlinux $(TARGET_DIR)/boot/vmlinux-arm-$(KERNEL_VER)
	install -m 644 $(KERNEL_DIR)/System.map $(TARGET_DIR)/boot/System.map-arm-$(KERNEL_VER)
	cp $(KERNEL_DIR)/arch/arm/boot/zImage $(TARGET_DIR)/boot/
	rm $(TARGET_DIR)/lib/modules/$(KERNEL_VER)/build || true
	rm $(TARGET_DIR)/lib/modules/$(KERNEL_VER)/source || true
	$(TOUCH)

kernel-distclean:
	rm -f $(D)/kernel
	rm -f $(D)/kernel.do_compile
	rm -f $(D)/kernel.do_prepare

kernel-clean:
	-$(MAKE) -C $(KERNEL_DIR) clean
	rm -f $(D)/kernel
	rm -f $(D)/kernel.do_compile

#
# Helper
#
kernel.menuconfig kernel.xconfig: \
kernel.%: $(D)/kernel
	$(MAKE) -C $(KERNEL_DIR) ARCH=arm CROSS_COMPILE=$(TARGET)- $*
	@echo ""
	@echo "You have to edit $(PATCHES)/armbox/$(KERNEL_CONFIG) m a n u a l l y to make changes permanent !!!"
	@echo ""
	diff $(KERNEL_DIR)/.config.old $(KERNEL_DIR)/.config
	@echo ""
