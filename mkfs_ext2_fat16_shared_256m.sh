#! /bin/sh --
#
# mkfs_ext2_fat16_shared_256m.sh: creates a disk image with both an ext2 and a FAT16 filesystem starting at the beginning, and sharing files
# by pts@fazekas.hu at Mon Apr 17 12:11:18 CEST 2023
#
# Motivation: https://askubuntu.com/a/1463980
#
# Filesystem size and statistics:
#
# * FAT16 data cluster size == ext2 block size == 4 KiB
# * partition (disk image) size == filesystem size == 256 MiB == 65536 blocks * 4 KiB per block
# * 65536 ext2 blocks in 2 ext2 block groups (32678 blocks each)
#   maximum file size == 65296 * 4 KiB == 267452416 bytes
#   65296 blocks of data in the file
#   64 indirect blocks, each pointing to 1024 file blocks (each 1 block number == 4 bytes)
#   1 doubly-indirect block, pointing to the 64 indirect block (each 1 block number == 4 bytes)
#   total number of data blocks == 65296 + 64 + 1 == 65361
# * 65536 4-KiB blocks in FAT16: 3 reserved blocks + 32 FAT blocks + 1 root directory block + 139 data clusters marked as bad + 65361 good data clusters
#   maximum file size == 65361 * 4 KiB == 267718656 bytes =~ 255.316 MiB
#
# Filesystem layout:
#
# * ext2 block group 0: (ext2 blocks 0..32767)
#   * block 0:
#     * first 512 bytes: FAT16 superblock (BPB, boot sector)
#     * next 512 bytes: ignored by FAT16 and ext2
#     * next 1024 bytes: ext2 primary superblock
#     * next 1024 bytes: ignored by FAT16 and ext2
#   * block 1: ext2 group descriptors, ignored by FAT16 (because it's reserved sector)
#   * block 2: ext2 block bitmap (1 bit per block in this ext2 block group), ignored by FAT16 (because it's reserved sector)
#   * block 3..34: marked as bad block in ext2, FAT16 FAT (65536 * 2 bytes: room for 65536 data clusters, 2 bytes per data cluster)
#   * block 35: marked as bad block in ext2, FAT16 root directory (128 * 32 bytes: room for 128 entries, 32 bytes per entry)
#   * block 36: ext2 inode bitmap, marked as bad block in FAT16, first FAT16 data cluster (data cluster 2) starts here
#   * block 37..100: ext2 inode table (2048 * 128 bytes: room for 2048 inodes, 128 bytes per inode, 11 inodes in use, why so many?), marked as bad block in FAT16
#   * block 101..106: ext2 used data blocks (root directory + lost+found directory, why so many (6) blocks?), marked as bad block in FAT16
#   * block 107..32767: free data blocks in both ext2 and FAT16 (32661 blocks)
# * ext2 block group 1: (ext2 blocks 32768..65535)
#   * block 32768: ext2 backup superblock, marked as bad block in FAT16
#   * block 32769: ext2 group descriptors (why do we need it here?), marked as bad block in FAT16
#   * block 32770: ext2 block bitmap (1 bit per block in this ext2 block group), marked as bad block in FAT16
#   * block 32771: ext2 inode bitmap, marked as bad block in FAT16
#   * block 32772..32835: ext2 inode table (2048 * 128 bytes: room for 2048 inodes, 128 bytes per inode, all free), marked as bad block in FAT16
#   * block 32836..65535: free data blocks in both ext2 and FAT16 (32700 blocks)
#
# Maximum filesystem size with this technique:
#
# * Use FAT32 instead of FAT16.
# * Maximum FAT32 FAT is limited by the ext2 block group size: each group
#   can contain up to 32695 data blocks (with the current inode ratio), if
#   we mark them all bad in ext2, then we have 32695 4 KiB-blocks for the
#   FAT32 FAT + root directory, thus 32694 4-KiB blocks for the FAT32 FAT,
#   thus (32694 * 4096 / 4) - 2 == 33478654 FAT32 data clusters, thus
#   33478654 * 32 KiB == 1071316928 bytes =~ 0.99774 TiB of free data.
# * 0.99774 TiB is possible for both ext2 and FAT32.
# * Using exFAT instead of FAT32 doesn't help, the ext2 block group limit
#   above still applies.
#

BLKDEV="${1:-bothsh.img}"
set -ex

dd if=/dev/zero bs=1M count=256 of="$BLKDEV"
# `*4' to convert from 4-KiB blocks to 1-KiB blocks.
(seq $((36*4)) $((106*4)) && seq $((32768*4)) $((32835*4))) >bb256m_fat16.lst
mkfs.fat -v -s 8 -S 512 -f 1 -F 16 -r 128 -R 24 -l bb256m_fat16.lst "$BLKDEV"
# Copy (save) the FAT16 superblock, mke2fs will overwrite it.
dd if="$BLKDEV" of="$BLKDEV".sb.tmp bs=512 count=1
# Copy (save) the FAT16 FAT, mke2fs will overwrite it.
dd if="$BLKDEV" of="$BLKDEV".fat.tmp bs=4K count=32 skip=3
seq 3 35 >bb256m_ext2.lst  # Counts 4 KiB blocks.
mke2fs -t ext2 -b 4096 -m 0 -O ^resize_inode -O ^dir_index -O ^sparse_super -I 128 -i 65536 -l bb256m_ext2.lst -F "$BLKDEV"
dumpe2fs "$BLKDEV"
# Restore the FAT16 superblock.
dd if="$BLKDEV".sb.tmp of="$BLKDEV" bs=512 count=1 conv=notrunc
# Restore the FAT16 FAT.
dd if="$BLKDEV".fat.tmp of="$BLKDEV" bs=4K count=32 conv=notrunc seek=3
rm -f "$BLKDEV".sb.tmp "$BLKDEV".fat.tmp
rm -f bb256m_fat16.lst bb256m_ext2.lst

# Mount it on Linux:
: mkdir p
: sudo mount -t ext2 -o loop,ro "$BLKDEV" p
: sudo umount p
: sudo mount -t vfat -o loop,ro "$BLKDEV" p
: sudo umount p

: "$0" OK.
