#! /bin/sh --
#
# mkfs_ext2_fat16.sh: creates a disk image with both an ext2 and a FAT16 filesystem starting at the beginning
# by pts@fazekas.hu at Mon Apr 17 09:21:17 CEST 2023
#
# Motivation: https://askubuntu.com/a/1463949
#
# Size: ~32 MiB for the ext2 filesystem, ~32 MiB of reserved sectors at the
# beginning of the FAT16 filesystem (right after the first 512 bytes) + ~32
# MiB FAT16 filesystem.
#
# The ext2 fileasystem can't be larger than ~32 MiB, because that's the upper
# limit of the reserved block count (stored on 16 bits) in a FAT filesystem.
# with an 512-byte sector size.
#

BLKDEV="${1:-bothfs.img}"
set -ex

dd if=/dev/zero bs=1M count=64 of="$BLKDEV"
mkfs.fat -v -s 8 -S 512 -f 1 -F 16 -r 64 -R 65528 "$BLKDEV" 65536  # Free blocks (largest file that can be created): 32752 KiB.
# Copy (save) the FAT16 superblock, mke2fs will overwrite it.
dd if="$BLKDEV" of="$BLKDEV".bs.tmp bs=1K count=1
# See https://unix.stackexchange.com/q/122771 about `mke2fs -E resize=...`
# and `mke2fs -O ^resize_inode`.
#mke2fs -t ext2 -b 1024 -m 0 -O ^resize_inode -O ^dir_index -I 128 -i 65536 -F "$BLKDEV" 32764  # Groups: 4. Free blocks: 32672 KiB. `-O sparse_super2` doesn't make a difference. Largest file that can be created: 32540 KiB.
#mke2fs -t ext2 -b 2048 -m 0 -O ^resize_inode -O ^dir_index -I 128 -i 65536 -F "$BLKDEV" 16382  # Groups: 1. Free blocks: 32674 KiB. Largest file that can be created: 32608 KiB.
mke2fs -t ext2 -b 4096 -m 0 -O ^resize_inode -O ^dir_index -I 128 -i 65536 -F "$BLKDEV" 8191  # Groups: 1. Free blocks: 32664 KiB. Largest file that can be created: 32628 KiB.
# Restore the FAT16 superblock.
dd if="$BLKDEV".bs.tmp of="$BLKDEV" bs=1K count=1 conv=notrunc
rm -f "$BLKDEV".bs.tmp
dumpe2fs "$BLKDEV"

: "$0" OK.

