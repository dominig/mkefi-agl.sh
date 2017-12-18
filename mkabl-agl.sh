#!/bin/sh
#
# Copyright (c) 2012, Intel Corporation.
# All rights reserved.
#
# This program is free software;  you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY;  without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See
# the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program;  if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA
#
# Modification from mkefidisk.sh provided by the Yocto project by Dominig
# to install Automotive Grade Linux (AGL) on 
# Intel platforms equipped with the Automotive Linux Boot (ABL)
#
# Dependencies:
# Relies on the Intel iasImage tool to pakage the Kernel and the initrd in ABL format
#
# changes
#         - simpler use model
#         - keep initrd if present
#         - does not allocate swap
#         - accept .hddimg, wic and wic.xz as sources
#

LANG=C

# Set to 1 to enable additional output
DEBUG=0
exec 3>/dev/null

#
# Defaults
#
# 100 Mb for the boot partition
BOOT_SIZE=100
# min available space on TMP_DIR for uncompressing xz image in kB e.g. 5G (5000000)
TMP_SIZE_MIN=5000000
# TMP_DIR directory use for holding image file for uncompression (e.g. /tmp or $HOME)
TMP_DIR=/tmp
#
MRB_DEBUG_TTY="ttyS2,115200n8"
MRB_HDMI="HDMI-A-1:e"
#
IAS_PATH=""
IAS_EXE="ias_image_app"
IAS_CMD_LINE=/tmp/iasCommandLine.cmd

# Cleanup after die()
cleanup() {
	debug "Syncing and unmounting devices"
	# Unmount anything we mounted
	unmount $ROOTFS_MNT || error "Failed to unmount $ROOTFS_MNT"
	unmount $BOOTFS_MNT || error "Failed to unmount $BOOTFS_MNT"
	unmount $HDDIMG_ROOTFS_MNT || error "Failed to unmount $HDDIMG_ROOTFS_MNT"
	unmount $HDDIMG_MNT || error "Failed to unmount $HDDIMG_MNT"
	if [ "$IMG_TYPE" = "DISK" ]; then
        debug "de-attaching loop devices"
        for LOOP_DEVICE in `losetup --list |grep $HDDIMG | cut -d" " -f1` ; do
           losetup -d $LOOP_DEVICE  1>&3 2>&1 || error "Detaching $LOOP_DEVICE from $HDDIMG failled"
        done   
     fi
	# Remove the TMPDIR
	debug "Removing temporary files"
	if [ -d "$TMPDIR" ]; then
		rm -rf $TMPDIR || error "Failed to remove $TMPDIR"
	fi
    [ -f "$TMP_DIR/TMP-AGL-wic-image.wic" ] || rm -f $TMP_DIR/TMP-AGL-wic-image.wic
}

trap 'die "Signal Received, Aborting..."' HUP INT TERM

# Logging routines
WARNINGS=0
ERRORS=0
CLEAR="$(tput sgr0)"
INFO="$(tput bold)"
RED="$(tput setaf 1)$(tput bold)"
GREEN="$(tput setaf 2)$(tput bold)"
YELLOW="$(tput setaf 3)$(tput bold)"
info() {
	echo "${INFO}$1${CLEAR}"
}
error() {
	ERRORS=$((ERRORS+1))
	echo "${RED}$1${CLEAR}"
}
warn() {
	WARNINGS=$((WARNINGS+1))
	echo "${YELLOW}$1${CLEAR}"
}
success() {
	echo "${GREEN}$1${CLEAR}"
}
die() {
	error "$1"
	cleanup
	exit 1
}
debug() {
	if [ $DEBUG -eq 1 ]; then
		echo "$1"
	fi
}

usage() {
	echo "Install AGL on a removable device to boot ABL based computer"
        echo "ABL on the target must accept non signed development Linux kernel"
	echo "In particular is can create USB or SD bootable support for Intel MRB"
	echo ""
	echo "Usage: $(basename $0) [-v] [-p path_to_iasImage_tool] HDDIMG REMOVABLE_DEVICE"
	echo "       -v: Verbose debug"
        echo "       path_to_iasImage_tool: path the iasImage tool provided by Intel."
	echo "       HDDIMG: The hddimg file to generate the efi disk from"
    echo "               Supported formats are .hddimg, .wic .wic.xz"
	echo "       REMOVABLE_DEVICE: The block device to write the image to, e.g. /dev/sdh"
	echo "ex:"
	echo "   mkabl-agl.sh   agl-demo-platform-intel-corei7-64.wic.xz /dev/sdd"
    echo "   mkabl-agl.sh   agl-demo-platform-intel-corei7-64.hddimg /dev/sdd"

        echo "                  assuming that iasImage is accessible via your default path"
	exit 1
}

image_details() {
	IMG=$1
	info "Image details"
	echo "    image: $(stat --printf '%N\n' $IMG)"
	echo "     size: $(stat -L --printf '%s bytes\n' $IMG)"
	echo " modified: $(stat -L --printf '%y\n' $IMG)"
	echo "     type: $(file -L -b $IMG)"
	echo ""
}

device_details() {
	DEV=$1
	BLOCK_SIZE=512

	info "Device details"
	echo "  device: $DEVICE"
	if [ -f "/sys/class/block/$DEV/device/vendor" ]; then
		echo "  vendor: $(cat /sys/class/block/$DEV/device/vendor)"
	else
		echo "  vendor: UNKOWN"
	fi
	if [ -f "/sys/class/block/$DEV/device/model" ]; then
		echo "   model: $(cat /sys/class/block/$DEV/device/model)"
	else
		echo "   model: UNKNOWN"
	fi
	if [ -f "/sys/class/block/$DEV/size" ]; then
		echo "    size: $(($(cat /sys/class/block/$DEV/size) * $BLOCK_SIZE)) bytes"
	else
		echo "    size: UNKNOWN"
	fi
	echo ""
}

unmount_device() {
	grep -q $DEVICE /proc/mounts
	if [ $? -eq 0 ]; then
		warn "$DEVICE listed in /proc/mounts, attempting to unmount"
		umount $DEVICE* 2>/dev/null
		! grep -q $DEVICE /proc/mounts && info "Unmounted successfully"
		return $?
	fi
	return 0
}

unmount() {
	if [ "$1" = "" ] ; then
		return 0
	fi
	grep -q $1 /proc/mounts
	if [ $? -eq 0 ]; then
		debug "Unmounting $1"
		umount $1
		! grep -q $1 /proc/mounts # check if unmounted successfully
		return $?
	fi
	return 0
}

#
# Parse and validate arguments
#

if [ "$1" = "-v" ] ; then
	DEBUG=1
	exec 3>&1
	shift
fi

if [ "$1" = "-p" ] ; then
        IAS_PATH="$2""/"
        shift 2
fi

if  [ $# -ne 2 ]; then
        usage
fi

IAS_IMAGE_TOOL="$IAS_PATH$IAS_EXE"
debug "iasImage tool is: $IAS_IMAGE_TOOL"
which $IAS_IMAGE_TOOL > IAS_IMAGE_TOOL_PATH
if  [ ! -x "$(command -v $IAS_IMAGE_TOOL)" ]; then
   die "$IAS_IMAGE_TOOL not found pointed by the path via 'sudo; use -p option'"
fi

HDDIMG=$1
DEVICE=$2

LINK=$(readlink $DEVICE)
if [ $? -eq 0 ]; then
	DEVICE="$LINK"
fi

if [ ! -w "$DEVICE" ]; then
	if [ ! -e "${DEVICE}" ] ; then
		die "Device $DEVICE cannot be found"
	else
		die "Device $DEVICE is not writable (need to run under sudo?)"
	fi
fi

if [ ! -e "$HDDIMG" ]; then
	die "HDDIMG $HDDIMG does not exist"
fi
HDDIMG_EXT=${HDDIMG##*.}
case $HDDIMG_EXT in
  hddimg)
     IMG_TYPE="MOUNT"
     IMG_COMPRESS="NO"
     debug "Detected: uncompressed image type .hddimg"
     ;;
  wic)
     IMG_TYPE="DISK"
     IMG_COMPRESS="NO"
     debug "Detected: uncompressed image type .wic"
     ;;
  xz)
     IMG_TYPE="DISK"
     IMG_COMPRESS="YES"
     debug "Detected: xz compressed image type .wic"
     command -v xz >/dev/null 2>&1 || { die "xz command is not available, pleaes install xz package"; }
     TMP_SIZE=`df -k $TMP_DIR | awk '/[0-9]%/{print $(NF-2)}'`
     if [ "$TMP_SIZE" -lt "$TMP_SIZE_MIN" ]; then
       die "Available space on $TMP_DIR must be at least $TMP_SIZE_MIN kB" 
     fi
     printf "Starting decompression of the image. It may take some time ..."
     xz --decompress --keep --format=auto --force --threads=0 --stdout > $TMP_DIR/TMP-AGL-wic-image.wic  $HDDIMG|| \
         die "xz command failled: xz --decompress --keep --format=auto --force --threads=0 --stdout > $TMP_DIR/TMP-AGL-wic-image.wic"
     HDDIMG="$TMP_DIR/TMP-AGL-wic-image.wic"
     echo "Image uncompressed, starting doing real work ..."
     ;;
  *)
     die "Unsupported image format: $HDDIMG_EXT Supported format are .hddimg .wic wic.xz"
     ;;
esac
#
# Ensure the hddimg is not mounted
#
debug "will now try to umount /detach previous images"
case $IMG_TYPE in
  MOUNT)
      unmount "$HDDIMG" || die "Failed to unmount $HDDIMG"
      ;;
  DISK)
      [ `losetup --list |grep $HDDIMG | wc -l ` -gt 1 ] && die "Image mounted more than once, manual cleaning required see: losetup --list"
      debug "ready to attach the wic image to aloop device"
      LOOP_DEVICE=`losetup --find --show $HDDIMG`  && ( losetup -d $LOOP_DEVICE  1>&3 2>&1 || die "Detaching $LOOP_DEVICE from $HDDIMG failled")
      ;;
  *)
      die "unknown image format $IMG_TYPE"
      ;;
esac
#
# Check if any $DEVICE partitions are mounted
#
unmount_device || die "Failed to unmount $DEVICE"

#
# Confirm device with user
#
image_details $HDDIMG
device_details $(basename $DEVICE)
echo -n "${INFO}Prepare ABL image on $DEVICE [y/N]?${CLEAR} "
read RESPONSE
if [ "$RESPONSE" != "y" ]; then
	echo "Image creation aborted"
	exit 0
fi


#
# Prepare the temporary working space
#
TMPDIR=$(mktemp -d mkabldisk-XXX) || die "Failed to create temporary mounting directory."
HDDIMG_MNT=$TMPDIR/hddimg
debug "TEMPDIR is: $TMPDIR"
HDDIMG_ROOTFS_MNT=$TMPDIR/hddimg_rootfs
ROOTFS_MNT=$TMPDIR/rootfs
BOOTFS_MNT=$TMPDIR/bootfs
mkdir $HDDIMG_MNT || die "Failed to create $HDDIMG_MNT"
mkdir $HDDIMG_ROOTFS_MNT || die "Failed to create $HDDIMG_ROOTFS_MNT"
mkdir $ROOTFS_MNT || die "Failed to create $ROOTFS_MNT"
mkdir $BOOTFS_MNT || die "Failed to create $BOOTFS_MNT"


#
# Partition $DEVICE
#
DEVICE_SIZE=$(parted -s $DEVICE unit mb print | grep ^Disk | cut -d" " -f 3 | sed -e "s/MB//")
# If the device size is not reported there may not be a valid label
if [ "$DEVICE_SIZE" = "" ] ; then
	parted -s $DEVICE mklabel msdos || die "Failed to create MSDOS partition table"
	DEVICE_SIZE=$(parted -s $DEVICE unit mb print | grep ^Disk | cut -d" " -f 3 | sed -e "s/MB//")
fi
ROOTFS_SIZE=$((DEVICE_SIZE-BOOT_SIZE))
ROOTFS_START=$((BOOT_SIZE))
ROOTFS_END=$((ROOTFS_START+ROOTFS_SIZE))

# MMC devices use a partition prefix character 'p'
PART_PREFIX=""
if [ ! "${DEVICE#/dev/mmcblk}" = "${DEVICE}" ] || [ ! "${DEVICE#/dev/loop}" = "${DEVICE}" ]; then
	PART_PREFIX="p"
fi
BOOTFS=$DEVICE${PART_PREFIX}1
ROOTFS=$DEVICE${PART_PREFIX}2

TARGET_PART_PREFIX=""
if [ ! "${TARGET_DEVICE#/dev/mmcblk}" = "${TARGET_DEVICE}" ]; then
	TARGET_PART_PREFIX="p"
fi
TARGET_ROOTFS=$TARGET_DEVICE${TARGET_PART_PREFIX}2

echo ""
info "Boot partition size:   $BOOT_SIZE MB ($BOOTFS)"
info "ROOTFS partition size: $ROOTFS_SIZE MB ($ROOTFS)"
echo ""

# Use MSDOS by default as GPT cannot be reliably distributed in disk image form
# as it requires the backup table to be on the last block of the device, which
# of course varies from device to device.

info "Partitioning installation media ($DEVICE)"

debug "Deleting partition table on $DEVICE"
dd if=/dev/zero of=$DEVICE bs=512 count=2 1>&3 2>&1 || die "Failed to zero beginning of $DEVICE"

debug "Creating new partition table (MSDOS) on $DEVICE"
parted -s $DEVICE mklabel msdos 1>&3 2>&1 || die "Failed to create MSDOS partition table"

debug "Creating boot partition on $BOOTFS"
parted -s $DEVICE mkpart primary 0% $BOOT_SIZE 1>&3 2>&1 || die "Failed to create BOOT partition"

debug "Enabling boot flag on $BOOTFS"
parted -s $DEVICE set 1 boot on 1>&3 2>&1 || die "Failed to enable boot flag"

debug "Creating ROOTFS partition on $ROOTFS"
parted -s $DEVICE mkpart primary $ROOTFS_START $ROOTFS_END 1>&3 2>&1 || die "Failed to create ROOTFS partition"

# as blkid does not provide PARTUUID on Ubuntu LTS 14.04 we myst hack via fdisk
#ROOTFS_PARTUUID=$(blkid |grep -e "$ROOTFS" |sed -n 's/^.*PARTUUID=/PARTUUID=/p')
export LC_ALL=C
ROOTFS_DISKID=$(fdisk -l "$DEVICE" | grep -e "Disk identifier" | sed -n 's/^.*Disk identifier: 0x/PARTUUID=/p')
if [ $ROOTFS_DISKID = "" ]; then
    die "Failed to read DISKID"
fi
ROOTFS_PARTUUID="$ROOTFS_DISKID-02"
debug "PARTUUID for ROOTFS is $ROOTFS_PARTUUID"

if [ $DEBUG -eq 1 ]; then
	parted -s $DEVICE print
fi


#
# Check if any $DEVICE partitions are mounted after partitioning
#
unmount_device || die "Failed to unmount $DEVICE partitions"


#
# Format $DEVICE partitions
#
info "Formatting partitions"
debug "Formatting $BOOTFS as ext2"
mkfs.ext2 -F -F -L BOOT $BOOTFS  1>&3 2>&1 || die "Failed to format $BOOTFS"

debug "Formatting $ROOTFS as ext4"
mkfs.ext4 -F $ROOTFS -L "ROOT" 1>&3 2>&1 || die "Failed to format $ROOTFS"


# Mounting image file system on loop devices
#
case $IMG_TYPE in

  MOUNT) 
     debug "Mounting images and device in preparation for installation"
     mount -o loop $HDDIMG $HDDIMG_MNT 1>&3 2>&1 || die "Failed to mount $HDDIMG"
     mount -o loop $HDDIMG_MNT/rootfs.img $HDDIMG_ROOTFS_MNT 1>&3 2>&1 || die "Failed to mount rootfs.img"
     ;;
  DISK)
     debug "Attaching image and mounting partitions then device in preparation for installation"
     LOOP_DEVICE=`losetup --find` || die "Failled to find an available loop device see: losetup --find"
     losetup -P $LOOP_DEVICE $HDDIMG  1>&3 2>&1 || die "Attaching $LOOP_DEVICE from $HDDIMG failled"
     mount "$LOOP_DEVICE"p2  $HDDIMG_ROOTFS_MNT 1>&3 2>&1 || die "Failed to mount $LOOP_DEVICEp1 on $HDDIMG_ROOTFS_MNT"
     mount "$LOOP_DEVICE"p1  $HDDIMG_MNT       1>&3 2>&1 || die "Failed to mount $LOOP_DEVICEp2 on $HDDIMG_MNT"
     ;;
  *)
      die "unknown image format $IMG_TYPE"
      ;;
esac

mount $ROOTFS $ROOTFS_MNT 1>&3 2>&1 || die "Failed to mount $ROOTFS on $ROOTFS_MNT"
mount $BOOTFS $BOOTFS_MNT 1>&3 2>&1 || die "Failed to mount $BOOTFS on $BOOTFS_MNT"

info "Preparing boot partition"
# create the config file for iasImage
# Remove any existing root= kernel parameters and:
# o Add a root= parameter with the target rootfs
# o Specify ro so fsck can be run during boot
# o Specify rootwait in case the target media is an asyncronous block device
#   such as MMC or USB disks
# o Specify "quiet" to minimize boot time when using slow serial consoles

# iasImage command line file creation
echo "root=$ROOTFS_PARTUUID"   > $IAS_CMD_LINE
echo "console=$MRB_DEBUG_TTY" >> $IAS_CMD_LINE
echo "earlycon=uart8250,mmio32,0xfc000000,115200n8" >> $IAS_CMD_LINE
echo "rootwait" >> $IAS_CMD_LINE
echo "video=$MRB_HDMI" >> $IAS_CMD_LINE
echo "i915.enable_initial_modeset=1" >> $IAS_CMD_LINE
debug "temp config for iasImage is $IAS_CMD_LINE"

if [ -f $HDDIMG_MNT/vmlinuz ]; then
   KERNEL_TYPE="vmlinuz"
   debug "kernel is vmlinuz"
fi
if [ -f $HDDIMG_MNT/bzimage ]; then
   KERNEL_TYPE="bzimage"
   debug "kernel is bzimage -> vmlinuz"
fi
if [ -f $HDDIMG_MNT/microcode.cpio ]; then
    die "initrd=microcode.cpio is not a supported configuration, change ycoto configuration or use an hddimg as source"
fi
[ -z $KERNEL_TYPE ] && die "Linux kernel type in $HDDIMG is unsupported"

if [ -f $HDDIMG_MNT/initrd ]; 
  then
     info "creating ABL image with initramsfs"
     debug "$IAS_IMAGE_TOOL -o  $BOOTFS_MNT/iasImage -i 0x30000 $IAS_CMD_LINE $HDDIMG_MNT/$KERNEL_TYPE $HDDIMG_MNT/initrd"
     $IAS_IMAGE_TOOL -o  $BOOTFS_MNT/iasImage -i 0x30000 $IAS_CMD_LINE $HDDIMG_MNT/$KERNEL_TYPE $HDDIMG_MNT/initrd
  else
     info "creating ABL image without initramfs"
     debug "$IAS_IMAGE_TOOL -o  $BOOTFS_MNT/iasImage -i 0x30000 $IAS_CMD_LINE $HDDIMG_MNT/$KERNEL_TYPE"
     $IAS_IMAGE_TOOL -o  $BOOTFS_MNT/iasImage -i 0x30000 $IAS_CMD_LINE $HDDIMG_MNT/$KERNEL_TYPE
fi     

printf "Copying ROOTFS files ... "
command -v rsync >/dev/null 2>&1 # check if rsync exists
if [ $DEBUG -eq 1 ] && [ $? -eq 0 ]; then
	rsync --info=progress2 -h -aHAXW --no-compress  $HDDIMG_ROOTFS_MNT/* $ROOTFS_MNT 1>&3 2>&1 || die "Root FS copy failed"
else
	cp -a $HDDIMG_ROOTFS_MNT/* $ROOTFS_MNT 1>&3 2>&1 || die "Root FS copy failed"
fi

debug "removing any swap entry in /etc/fstab"
sed --in-place '/swap/d' $ROOTFS_MNT/etc/fstab 

printf "flushing data on removable device. May take a while ... "
sync --file-system $ROOTFS_MNT
echo done

# We dont want udev to mount our root device while we're booting...
if [ -d $ROOTFS_MNT/etc/udev/ ] ; then
	echo "$TARGET_DEVICE" >> $ROOTFS_MNT/etc/udev/mount.blacklist
fi


# Call cleanup to unmount devices and images and remove the TMPDIR
cleanup

echo ""
if [ $WARNINGS -ne 0 ] && [ $ERRORS -eq 0 ]; then
	echo "${YELLOW}Installation completed with warnings${CLEAR}"
	echo "${YELLOW}Warnings: $WARNINGS${CLEAR}"
elif [ $ERRORS -ne 0 ]; then
	echo "${RED}Installation encountered errors${CLEAR}"
	echo "${RED}Errors: $ERRORS${CLEAR}"
	echo "${YELLOW}Warnings: $WARNINGS${CLEAR}"
else
	success "Installation completed successfully"
fi
echo ""
