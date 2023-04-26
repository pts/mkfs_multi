#! /bin/sh --
#
# mkfs_ext2_fat16_shared_256m.sh: creates a disk image with both an ext2 and a FAT16 filesystem starting at the beginning, and sharing files
# by pts@fazekas.hu at Mon Apr 17 12:11:18 CEST 2023
#
# Motivation: https://askubuntu.com/a/1463980
#
# Filesystem type, size and statistics:
#
# * The first filesystem is ext2 (could easily be ext3, ext4 or even minix), the second filesystem is FAT16 (could easily be FAT32 or exFAT).
# * FAT16 data cluster size == ext2 block size == 4 KiB
# * FAT16 sector size == 512 bytes, for compatibility with old FAT16 drivers
# * partition (disk image) size == filesystem size == 256 MiB == 65536 blocks * 4 KiB per block
# * 65536 ext2 blocks in 2 ext2 block groups (32678 blocks each)
#   maximum file size == 65296 * 4 KiB == 267452416 bytes
#   65296 blocks of data in the file
#   the inode itself points to 12 file data blocks
#   64 indirect blocks, each pointing to 1024 file data blocks (each 1 block number == 4 bytes)
#   1 doubly-indirect block, pointing to the 64 indirect blocks (each 1 block number == 4 bytes)
#   total number of data blocks == 65296 + 64 + 1 == 65361
# * 65536 4-KiB blocks in FAT16: 3 reserved blocks + 32 FAT blocks + 1 root directory block + 139 data clusters marked as bad + 65361 good data clusters
#   maximum file size == 65361 * 4 KiB == 267718656 bytes =~ 255.316 MiB
#
# Filesystem layout:
#
# * ext2 block group 0: (ext2 blocks 0..32767)
#   * block 0:
#     * first 512 bytes: FAT16 superblock (BPB, boot sector), ignored by ext2 (because ext2 ignores the first 1024 bytes of the filesystem)
#     * next 512 bytes: ignored by FAT16 (because it's in a reserved sector) and ext2 (because ext2 ignores the first 1024 bytes of the filesystem)
#     * next 1024 bytes: ext2 primary superblock (always at offset 1024), ignored by FAT16 (because it's in a reserved sector)
#     * last 2048 bytes: ignored by FAT16 (because it's in a reserved sector) and ext2 (because the next ext2 block starts at offset 4096)
#   * block 1: ext2 group descriptors, ignored by FAT16 (because it's in a reserved sector)
#   * block 2: ext2 block bitmap (1 bit per block in this ext2 block group), ignored by FAT16 (because it's in a reserved sector)
#   * block 3..34: marked as bad block in ext2, FAT16 FAT (65536 * 2 bytes: room for 65536 data clusters, 2 bytes per data cluster)
#   * block 35: marked as bad block in ext2, FAT16 root directory (128 * 32 bytes: room for 128 entries, 32 bytes per entry)
#   * block 36: ext2 inode bitmap, marked as bad block in FAT16, first FAT16 data cluster (data cluster 2) starts here
#   * block 37..100: ext2 inode table (2048 * 128 bytes: room for 2048 inodes, 128 bytes per inode, 11 inodes in use, why so many?), marked as bad block in FAT16
#   * block 101: ext2 data block containing directory entries for the root directory (/), marked as bad block in FAT16
#   * block 102..105: ext2 data block containing directory entries for the /lost+found directory, marked as bad block in FAT16
#   * block 106: ext2 data block containing indirect block used by inode <1> (bad blocks), marked as bad block in FAT16
#   * block 107..32767: free data blocks in both ext2 and FAT16 (32661 blocks)
# * ext2 block group 1: (ext2 blocks 32768..65535)
#   * block 32768: ext2 backup superblock, marked as bad block in FAT16
#   * block 32769: ext2 group descriptors (why do we need it here?), marked as bad block in FAT16
#   * block 32770: ext2 block bitmap (1 bit per block in this ext2 block group), marked as bad block in FAT16
#   * block 32771: ext2 inode bitmap, marked as bad block in FAT16
#   * block 32772..32835: ext2 inode table (2048 * 128 bytes: room for 2048 inodes, 128 bytes per inode, all free), marked as bad block in FAT16
#   * block 32836..65535: free data blocks in both ext2 and FAT16 (32700 blocks)
#
# ext2 inodes (128 bytes each):
#
# * inode <0>: 0 is an invalid inode number, it's not even stored in the filesystem
# * inode <1> == EXT2_BAD_INO at offset 151552: bad blocks: mode == 0, size == 135168 (total number of bytes in 33 bad blocks), 33 data blocks: (0..11):3..14, (12..32):15..35, 1 indirect block: 106 (contains the block numbers 15..35, 4 bytes each)
# * inode <2> == EXT2_ROOT_INO at offset 151680: directory /: mode == 0x41ed, size == 4096, 1 data block: (0):101
# * inode <3> == EXT2_ACL_IDX_INO == EXT4_USR_QUOTA_INO at offset 151808: mode == size == 0, unused, not defined in ext2.h
# * inode <4> == EXT2_ACL_DATA_INO == EXT4_GRP_QUOTA_INO at offset 151936: mode == size == 0, unused, not defined in linux/fs/ext2/ext2.h
# * inode <5> == EXT2_BOOT_LOADER_INO at offset 152064: mode == size == 0, unused, not defined in linux/fs/ext2/ext2.h
# * inode <6> == EXT2_UNDEL_DIR_INO at offset 152192: mode == size == 0, unused
# * inode <7> == EXT4_RESIZE_INO at offset 152320: mode == size == 0, unused, reserved group descriptors
# * inode <8> == EXT4_JOURNAL_INO at offset 152448: mode == size == 0, unused
# * inode <9>..<10> at offset 152576: mode == size == 0, unused, remaining reserved inode (there are 10 in total)
# * inode <11> at offset 152832: directory /lost+found: mode == 0x41c0, size == 16384 (4096 could be enough, or no lost+found at all, but mke2fs leaves enough room free on purpose), 4 data blocks: (0..3):102-105
# * inode <12>..<2048> at offset 152960: free inodes
# * inode <2049>..<4096> at offset 134234112: free inodes
#
# ext2 directory entries:
#
# * for inode <2> (/):
#   * data block 101 at offset 413696:
#     * inode <2> (.) 12 bytes: inode=<2> size=12 name_size=1 type=2=DT_DIR name="."
#     * inode <2> (..) 12 bytes: inode=<2> size=12 name_size=2 type=2=DT_DIR name=".."
#     * inode <11> (lost+found): inode=<11> size=4072 name_size=10 type=2=DT_DIR name="lost+found"
# * for inode <11> (/lost+found):
#   * data block 102 at offset 417792
#     * inode <11> (.) 12 bytes: inode=<11> size=12 name_size=1 type=2=DT_DIR name="."
#     * inode <2> (..) 4084 bytes: inode=<2> size=4084 name_size=2 type=2=DT_DIR name=".."
#   * data block 103 at offset 421888: empty
#     * empty: 4096 bytes: inode=0 size=4096 name_size=0 type=0=DT_UNKNOWN
#   * data block 104 at offset 425984: empty
#     * empty: 4096 bytes: inode=0 size=4096 name_size=0 type=0=DT_UNKNOWN
#   * data block 105 at offset 430080: empty
#     * empty: 4096 bytes: inode=0 size=4096 name_size=0 type=0=DT_UNKNOWN
#
# One way to populate the filesystem with files (needs software development):
#
# * Mount the ext2 filesystem as read-write. Do all modifications. Unmount
#   the ext2 filesystem.
# * Run the recreator tool, which does a recursive listing on the ext2
#   filesystem (read-only), recreates and writes all the FAT16 metadata
#   based on the listing, and it marks some ext2 blocks (corresponding to
#   FAT16 subdirectory clusters) as a bad block. The recreator tool doesn't
#   exist yet, but it can be written given enough motivation. it will work
#   like this:
#   * It reads and analyzes the ext2 superblock, the ext2 block groups and
#     FAT16 superblock (BPB, boot sector), and fails if they don't
#     correspond to each other.
#   * It does a recursive listing on the ext2 filesystem without mounting
#     it. (It understands the metadata.) As part of the recursive listing,
#     it discovers the data block list of each regular file.
#   * It marks most ext2 bad blocks as free, removing them from the list of
#     bad blocks. The only remaining ext2 bad blocks are those which
#     correspond to the FAT16 FAT and the FAT16 root directory.
#   * It creates an empty FAT16 FAT with all clusters free. Based on the
#     ext2 block bitmap, it marks all used ext2 blocks as a bad block in the
#     FAT16 FAT. It overwrites the FAT16 FAT accordingly.
#   * For each regular file discovered during the recursive ext2 listing, it
#     builds a FAT16 FAT data cluster chain containing the ext2 file data
#     blocks (not the ext2 indirect blocks) of that file. It updates or
#     overwrites the FAT16 FAT accordingly.
#   * Based on the directories and regular files discovered during the
#     recursive ext2 listing, it builds the FAT16 long filenames (VFAT,
#     UTF-16, UCS-2) and directory entries from scratch in memory, and it
#     organizes them into FAT16 data clusters (at least one cluster per
#     subdirectory, with a special cluster offset for the root directory).
#     It writes the FAT16 data clusters and the root directory. For each
#     subdirectory, it builds a FAT16 FAT data cluster chain. It updates or
#     overwrites the FAT16 FAT accordingly. It marks each FAT16 data cluster
#     (used by newly created FAT16 subdirectories) as an ext2 bad block. For
#     that it may have to extend the ext2 inode storing the list of bad
#     blocks with more ext2 file indirect blocks. For each new ext2 file
#     indirect block, it marks the corresponding FAT16 cluser as a bad block
#     in the FAT16 FAT.
#   * Maybe some of the ext2 operations above can be done by using the
#     *debugfs* tool, thus making the implementation of the recreator tool
#     simpler. However, the recreator tool needs to fully understand the
#     FAT16 filesystem (which is relatively easy).
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
