## Introduction
This script will install the AGL distribution on a removable device to boot on Intel platform.
 - Device booting UEFI-based computer are created with `mkefi-agl.sh`
 - Device booting with Automotive Boot Loader (ABL) are created with `mkabl-agl.sh`
 
    *Note:* a development release of ABL accepting an unsigned kernel is required.

So it's easy to create a USB or SD bootable support for [MinnowBoard](http://www.minnowboard.org), a PC or an Intel Automotive Reference Platform (MRB).

## Usage:
### UEFI
```
   mkefi-agl.sh [-v] HDDIMG REMOVABLE_DEVICE
       -v: verbose debug
       HDDIMG: the hddimg file to generate the UEFI disk from
       REMOVABLE_DEVICE: the block device to write the image to, e.g. /dev/sdh
```
Example: `mkefi-agl.sh agl-demo-platform-intel-corei7-64.hddimg /dev/sdd`
 
### ABL
```
mkabl-agl.sh [-v] [-p path_to_iasImage_tool] HDDIMG REMOVABLE_DEVICE
       -v: verbose debug
       -p: path to iasImage_app binary provided by Intel
       HDDIMG: the hddimg file to generate the ABL disk from
       REMOVABLE_DEVICE: the block device to write the image to, e.g. /dev/sdh
```

## Documentation
Additional documentation: https://wiki.automotivelinux.org/agl-distro/developer_resources_intel

## opensafe.sh closesafe.sh
2 small bash scripts helping management of encrypted directory using encfs fuse module
  encrypted dir are created with an auto close timeout of 30mn
  dependency: fusefs encfs
Usage:
 Intialisation
    create a directory (e.g. MyDir) in $HOME
 Opening safe
  opensafe.sh MyDir
      first time
         you will be asked password and configuration questions
         Note: quick paranoid mode is not compatible with hard link
               manual setup is required to support hardlinks
  copy/delete/modify files in MyDir
 Closing safe
  closesafe.sh MyDir

Encrypted dir is created automatically and is name .MyDir
