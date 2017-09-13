## Introduction
This script will install the AGL distribution on a removable device to boot on Intel platform.
 - Device booting UEFI-based computer are createdwith mkefi-agl.sh.
 - Device booting with Automotive Boot Loader (ABL) are created with mfabl-agl.sh
   Note: a development release of ABL accepted non signed Kernel is required.
So it's easy to create a USB or SD bootable support for (MinnowBoard)[www.minnowboard.org], a PC or an Intel Automotive Reference Platform (MRB).

Usage:
 UEFI
    mkefi-agl.sh [-v] HDDIMG REMOVABLE_DEVICE
       -v: verbose debug
       HDDIMG: the hddimg file to generate the UEFI disk from
       REMOVABLE_DEVICE: the block device to write the image to, e.g. /dev/sdh

Example: `mkefi-agl.sh agl-demo-platform-intel-corei7-64.hddimg /dev/sdd`
 
 ABL
   mkjabl-agl.sh [-v] [-p path_to_iasImage_tool] HDDIMG REMOVABLE_DEVICE
       -v: verbose debug
       -p: path to iasImage_app binary provided by Intel
       HDDIMG: the hddimg file to generate the ABL disk from
       REMOVABLE_DEVICE: the block device to write the image to, e.g. /dev/sdh


## Documentation
Additional documentation: https://wiki.automotivelinux.org/agl-distro/developer_resources_intel
