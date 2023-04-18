# mkfs_multi: create multiple filesystems starting at the beginning on Linux

mkfs_multi is a collection of Linux shell scripts for creating multiple
filesystems on the same partition (or disk image), starting at the beginning
(offset 0) in a way that both filesystems can be mounted on Linux (but not
at the same time).

See also https://askubuntu.com/a/1463949 and https://askubuntu.com/a/1463980
for motivation.

The filesystems created by mkfs_multi are proof-of-concepts: they have
academic, hacking and demonstration value, but they are not practical for
production use. That's because either the filesystems don't share file data
(i.e. the partition stores 2 copies of each file) or they are read-only. For
read-only use, a single filesystem would be enoguh, because most modern
operating systems can read a
[UDF filesystem (ufs)](https://en.wikipedia.org/wiki/Universal_Disk_Format)
or an
[exFAT filesystem](https://en.wikipedia.org/wiki/ExFAT).

Included Linux shell scripts:

* mkfs_ext2_fat16.sh: ext2 and FAT16 filesystems, contains each file twice.

* mkfs_minix_fat16.sh: ext2 and Minix filesystems, contains each file twice.

* mkfs_ext2_fat16_shared_256m.sh: ext2 and FAT16 filesystems, can share file
  data. The filesystems are created empty, file sharing is not demonstrated
  (but can be implemented in the future). The filesystems are designed for
  read-only use after the files have been created.

<!-- __END__ -->
