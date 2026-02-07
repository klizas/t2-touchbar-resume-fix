KVER       ?= $(shell uname -r)
KBUILD     := /lib/modules/$(KVER)/build
BUILDDIR   := $(CURDIR)/build
INSTALL_DIR := /lib/modules/$(KVER)/updates
PATCH      := $(CURDIR)/hid-appletb-kbd-add-resume.patch
MODULE     := $(BUILDDIR)/hid-appletb-kbd.ko
BASE_KVER  := $(firstword $(subst -, ,$(KVER)))
KERNEL_GIT := https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git/plain/drivers/hid

.PHONY: all install uninstall clean

all: $(MODULE)

$(MODULE): $(BUILDDIR)/.patched $(BUILDDIR)/Kbuild
	$(MAKE) -C $(KBUILD) M=$(BUILDDIR) modules
	@VERMAGIC=$$(modinfo $@ | awk '/vermagic/{print $$2}'); \
	if [ "$$VERMAGIC" != "$(KVER)" ]; then \
		echo "ERROR: vermagic mismatch: module has '$$VERMAGIC', kernel is '$(KVER)'"; \
		exit 1; \
	fi; \
	echo "==> Module built successfully (vermagic: $$VERMAGIC)"

$(BUILDDIR)/Kbuild: | $(BUILDDIR)
	@printf 'obj-m += hid-appletb-kbd.o\n' > $@

$(BUILDDIR)/.patched: $(BUILDDIR)/hid-appletb-kbd.c $(PATCH)
	@if ! grep -q '\.resume = appletb_kbd_resume,' $<; then \
		echo "==> Applying patch..."; \
		cd $(BUILDDIR) && patch -p3 < $(PATCH); \
	else \
		echo "==> Patch already applied"; \
	fi
	@touch $@

$(BUILDDIR)/hid-appletb-kbd.c: | $(BUILDDIR)
	@SRC=""; \
	for dir in \
		"$$(readlink -f $(KBUILD) 2>/dev/null)/drivers/hid" \
		"$$(readlink -f /lib/modules/$(KVER)/source 2>/dev/null)/drivers/hid" \
		/usr/src/linux/drivers/hid \
		/usr/src/linux-*/drivers/hid; \
	do \
		[ -f "$$dir/hid-appletb-kbd.c" ] && SRC="$$dir" && break; \
	done; \
	if [ -n "$$SRC" ]; then \
		echo "==> Using local kernel source: $$SRC"; \
		cp "$$SRC/hid-appletb-kbd.c" "$$SRC/hid-ids.h" $(BUILDDIR)/; \
	else \
		echo "==> Downloading source for v$(BASE_KVER) from kernel.org..."; \
		curl -fSL "$(KERNEL_GIT)/hid-appletb-kbd.c?h=v$(BASE_KVER)" -o $(BUILDDIR)/hid-appletb-kbd.c; \
		curl -fSL "$(KERNEL_GIT)/hid-ids.h?h=v$(BASE_KVER)" -o $(BUILDDIR)/hid-ids.h; \
	fi

$(BUILDDIR):
	mkdir -p $@

install: $(MODULE)
	install -d $(INSTALL_DIR)
	install -m 644 $(MODULE) $(INSTALL_DIR)/
	depmod -a $(KVER)
	@if command -v mkinitcpio >/dev/null 2>&1; then \
		echo "==> Rebuilding initramfs (mkinitcpio)..."; \
		mkinitcpio -P; \
	elif command -v update-initramfs >/dev/null 2>&1; then \
		echo "==> Rebuilding initramfs (update-initramfs)..."; \
		update-initramfs -u; \
	elif command -v dracut >/dev/null 2>&1; then \
		echo "==> Rebuilding initramfs (dracut)..."; \
		dracut --force; \
	else \
		echo "WARNING: No initramfs tool found (mkinitcpio/update-initramfs/dracut)."; \
		echo "         You may need to rebuild your initramfs manually."; \
	fi
	@echo "==> Done. Reboot to use the patched module."

uninstall:
	rm -f $(INSTALL_DIR)/hid-appletb-kbd.ko
	depmod -a $(KVER)
	@if command -v mkinitcpio >/dev/null 2>&1; then \
		mkinitcpio -P; \
	elif command -v update-initramfs >/dev/null 2>&1; then \
		update-initramfs -u; \
	elif command -v dracut >/dev/null 2>&1; then \
		dracut --force; \
	else \
		echo "WARNING: No initramfs tool found. Rebuild your initramfs manually."; \
	fi
	@echo "==> Uninstalled. Reboot to restore the stock module."

clean:
	rm -rf $(BUILDDIR)
