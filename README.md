# Touch Bar Resume Fix for T2 MacBooks (Linux)

On T2 MacBooks running Linux, the Touch Bar goes blank after suspend/resume and
does not come back until reboot.

The kernel driver `hid-appletb-kbd` is missing a `.resume` callback. During
suspend it turns the Touch Bar off, but on normal resume it never turns it back
on. This patch adds the missing callback.

Tested on a MacBookPro 16,1 with the standard Touch Bar (no tiny-dfr) running
kernel 6.18. Should work on any kernel version that ships `hid-appletb-kbd`.

## Quick Start

```bash
git clone https://github.com/klizas/t2-touchbar-resume-fix.git
cd t2-touchbar-resume-fix
make
sudo make install
# Reboot
```

The Makefile automatically:
- Finds local kernel source, or downloads the matching files from kernel.org
- Applies the patch
- Builds the module and verifies it matches your running kernel
- Installs the module and rebuilds your initramfs

## Requirements

- Linux kernel headers for your running kernel
- `make`, `patch`, `curl`, `gcc`

### Distro-specific header packages

| Distro | Package |
|---|---|
| Arch / CachyOS | `linux-headers` (or `linux-cachyos-headers`, etc.) |
| Ubuntu / Debian | `linux-headers-$(uname -r)` |
| Fedora | `kernel-devel` |
| openSUSE | `kernel-devel` |

## What the Patch Does

The driver defines `.reset_resume` (called after USB device reset) but not
`.resume` (called on normal resume). Since most suspend/resume cycles take the
normal path, the Touch Bar stays off.

The patch adds a `.resume` callback identical to `.reset_resume`:

```c
static int appletb_kbd_resume(struct hid_device *hdev)
{
    struct appletb_kbd *kbd = hid_get_drvdata(hdev);
    appletb_kbd_set_mode(kbd, kbd->saved_mode);
    return 0;
}
```

## Build Options

Build for a different kernel version:

```bash
make KVER=6.18.9-2-cachyos
```

Use clang instead of gcc:

```bash
make CC=clang LLVM=1
```

## Verifying

After reboot, confirm the patched module is loaded:

```bash
modinfo hid-appletb-kbd | grep filename
# Expected: /lib/modules/<version>/updates/hid-appletb-kbd.ko
```

## Uninstalling

```bash
sudo make uninstall
# Reboot
```
