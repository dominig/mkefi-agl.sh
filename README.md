## Introduction
This script will install the AGL distribution on a removable device to boot on Intel UEFI-based computer.

In particular it can create a USB or SD bootable support for (MinnowBoard)[www.minnowboard.org].

Usage:

    mkefi-agl.sh [-v] HDDIMG REMOVABLE_DEVICE
       -v: verbose debug
       HDDIMG: the hddimg file to generate the efi disk from
       REMOVABLE_DEVICE: the block device to write the image to, e.g. /dev/sdh

Example: `mkefi-agl.sh agl-demo-platform-intel-corei7-64.hddimg /dev/sdd`

## Documentation
Additional documentation: https://wiki.automotivelinux.org/agl-distro/developer_resources_intel
