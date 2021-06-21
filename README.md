# kvm-borg-backup

## What is does
This script creates external backups of (running) KVM/QEMU VM's. Instead of copying the image files to some backup location, it uses a BorgBackup repository. This enables encryption, compression and deduplication of the images.

The VM's must use image files that support snapshots (qcow2). If a VM has another type of disk, raw for instance, it will be skipped. You can backup a raw image based VM, if it is shut down first.

**I only tested qcow2 and raw disks, you will have to test other types yourself.**

Below is an example of the output.

From inside the VM:
```
[arch@main ~]$ df -h
Filesystem      Size  Used Avail Use% Mounted on
dev             972M     0  972M   0% /dev
run             990M  660K  990M   1% /run
/dev/vda1        63G   15G   46G  24% /
tmpfs           990M  188K  990M   1% /dev/shm
tmpfs           990M     0  990M   0% /tmp
tmpfs           198M     0  198M   0% /run/user/1000
```
Backup output (this repo contains 5 backups):
```
------------------------------------------------------------------------------
Archive name: archlinux-2021-06-21T12:27:49
Archive fingerprint: e4509ef9efe9ad00f039c9091c6a2d7011366dab8f0ce476641ef1f71fafa4ad
Time (start): Mon, 2021-06-21 12:27:50
Time (end):   Mon, 2021-06-21 12:32:48
Duration: 4 minutes 58.95 seconds
Number of files: 2
Utilization of max. archive size: 0%
------------------------------------------------------------------------------
                       Original size      Compressed size    Deduplicated size
This archive:               46.02 GB             19.50 GB             28.08 MB
All archives:              224.10 GB             96.32 GB             20.88 GB

                       Unique chunks         Total chunks
Chunk index:                   17106                78943
------------------------------------------------------------------------------
terminating with success status, rc 0

```

Based on the folloing scripts/documentation:

https://nixlab.org/blog/backup-kvm-virtual-machines

https://www.ludovicocaldara.net/dba/bash-tips-4-use-logging-levels/

https://borgbackup.readthedocs.io/en/1.1.16/quickstart.html
