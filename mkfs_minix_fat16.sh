#! /bin/sh --
#
# mkfs_minux_fat16.sh: creates a disk image with both a Minix and a FAT16 filesystem starting at the beginning
# by pts@fazekas.hu at Mon Apr 17 09:21:17 CEST 2023
#
# Motivation: https://askubuntu.com/a/1463949
#
# Size: ~32 MiB for the Minix filesystem, ~32 MiB of reserved sectors at the
# beginning of the FAT16 filesystem (right after the first 512 bytes) + ~32
# MiB FAT16 filesystem.
#
# The Minix fileasystem can't be larger than ~32 MiB, because that's the upper
# limit of the reserved block count (stored on 16 bits) in a FAT filesystem
# with an 512-byte sector size.
#

BLKDEV="${1:-bothfs.img}"
set -ex

dd if=/dev/zero bs=1M count=64 of="$BLKDEV"
mkfs.fat -v -s 8 -S 512 -f 1 -F 16 -r 64 -R 65528 "$BLKDEV" 65536  # Free blocks (largest file that can be created): 32752 KiB.
# Copy (save) the FAT16 superblock, mke2fs will overwrite it.
dd if="$BLKDEV" of="$BLKDEV".bs.tmp bs=1K count=1
# minix v1: >=32 inodes, inode count multiple of 32.
#mkfs.minix -1 -n 14 -i 512 "$BLKDEV" 32764  # Largest file that can be created: 32672 KiB.
mkfs.minix -1 -n 14 -i 32 "$BLKDEV" 32764  # Largest file that can be created: 32688 KiB.
# Restore the FAT16 superblock.
dd if="$BLKDEV".bs.tmp of="$BLKDEV" bs=1K count=1 conv=notrunc
rm -f "$BLKDEV".bs.tmp
#dumpe2fs "$BLKDEV"

# Mount it on Linux:
: mkdir p
: sudo mount -t minix -o loop "$BLKDEV" p
: sudo umount p
: sudo mount -t vfat -o loop "$BLKDEV" p
: sudo umount p

: "$0" OK.
