Install AGL on a removable device to boot on IA UEFI based computer
In particular is can create USB or SD bootable support for Minnowboard

Usage: mkefi-agl.sh [-v] HDDIMG REMOVABLE_DEVICE
       -v: Verbose debug
       HDDIMG: The hddimg file to generate the efi disk from
       REMOVABLE_DEVICE: The block device to write the image to, e.g. /dev/sdh
ex:
   mkefi-agl.sh   agl-demo-platform-intel-corei7-64.hddimg /dev/sdd

DOCUMENTATION
https://wiki.automotivelinux.org/agl-distro/developer_resources_intel
