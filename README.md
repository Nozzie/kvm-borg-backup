# kvm-borg-backup

## What is does
This script creates external backups of (running) KVM/QEMU VM's. Instead of copying the image files to some backup location, it uses a BorgBackup repository. This enables encryption, compression and deduplication of the images.

The VM's must use image files that support snapshots (qcow2). If a VM has another type of disk, raw for instance, it will be skipped. You can backup a raw image based VM, if it is shut down first.

**I only tested qcow2 and raw disks, you will have to test other types yourself.**
## Usage
When run without any arguments, all VM's will be backed up. You can exclude VM's form being backed up by putting them in the EXCLUDE_LIST array.  
If you give a VM name as the first argument, only that VM will be backed up (even if it is in the EXCLUDE_LIST).  

## Output
You can enable or disable output to stdout by setting STDOUT_LOG to true/false. When set to false, output will still be logged to the logfile.  

## Example

From inside the VM:
```
[arch@main ~]$ df -h
Filesystem      Size  Used Avail Use% Mounted on
dev             983M     0  983M   0% /dev
run             991M  672K  990M   1% /run
/dev/vda1        63G   15G   46G  25% /
tmpfs           991M   36K  991M   1% /dev/shm
tmpfs           991M  1.2M  990M   1% /tmp
tmpfs           199M     0  199M   0% /run/user/1000
```
Image file:
```
[nozz@host ~]$ ls -lh /var/lib/libvirt/images/arch_linux.qcow2
-rw-r--r-- 1 nobody kvm 56G Aug 22 10:04 /var/lib/libvirt/images/arch_linux.qcow2
```
Repository size on disk:
```
[nozz@host ~]$ du -sh /storage/vmbackup/archlinux
34G     /storage/vmbackup/archlinux
```
Borg info output:
```
[arch@main ~]$ borg info /storage/vmbackup/archlinux
Enter passphrase for key /storage/vmbackup/archlinux:
Repository ID: 15094b263afadff74fad605a4ef27e5a37affd3d16209e5b42e147ea2a27fa79
Location: /storage/vmbackup/archlinux
Encrypted: Yes (repokey BLAKE2b)
Cache: /root/.cache/borg/15094b263afadff74fad605a4ef27e5a37affd3d16209e5b42e147ea2a27fa79
Security dir: /root/.config/borg/security/15094b263afadff74fad605a4ef27e5a37affd3d16209e5b42e147ea2a27fa79
------------------------------------------------------------------------------
                       Original size      Compressed size    Deduplicated size
All archives:                1.02 TB            456.71 GB             34.06 GB

                       Unique chunks         Total chunks
Chunk index:                   27612               351011

```
Borg list output:
```
[arch@main ~]$ borg list /storage/vmbackup/archlinux
Enter passphrase for key /storage/vmbackup/archlinux:
archlinux-2021-07-18T04:05:02        Sun, 2021-07-18 04:05:02 [d736a8f377894c33b0898c46f6d511956f4e55b1c2f6a305b76284354727f431]
archlinux-2021-07-25T04:05:02        Sun, 2021-07-25 04:05:03 [a4a04f2f07e673e354bb883ccebe30e57e49a62633cd178d41396b92b6afa174]
archlinux-2021-08-01T04:05:02        Sun, 2021-08-01 04:05:03 [62a948e2afb48de3ddbc951cf840fce661370077ffde71f07d1e716414939e81]
archlinux-2021-08-08T04:05:01        Sun, 2021-08-08 04:05:01 [6994aa45b932670efd3261a97e0a093feb03bd49b166bffa45c487f129edd342]
archlinux-2021-08-09T04:05:02        Mon, 2021-08-09 04:05:03 [369362fd5f77fbcf3ce222dfbecf364f6c2943fc296ed6d519d84194e00ff7fb]
archlinux-2021-08-10T04:05:02        Tue, 2021-08-10 04:05:02 [4db8ef5e1ea430fc68c1f7572bd9a481b3b13e6d9fb0480c1d8e9dac34502e1e]
archlinux-2021-08-11T04:05:02        Wed, 2021-08-11 04:05:02 [b6bd34b7f4a6d33c7e68ddb5488963ea9547c9a012e1952792cdb6a9e6dd1556]
archlinux-2021-08-12T04:05:02        Thu, 2021-08-12 04:05:03 [64b67b45e9d60ca44ad5973fe8acb7acaaf149f15ee8050ec6413b5bc6493ac9]
archlinux-2021-08-13T04:05:01        Fri, 2021-08-13 04:05:02 [a7211cc7e58b16fa89c58455c85412bd119a8b00695e26f25c3814bbf98e4592]
archlinux-2021-08-14T04:05:01        Sat, 2021-08-14 04:05:03 [efeb1e3f16821b7a491bccf62c6af5cf9b1d336d7c6f732392922b8e61a8aa00]
archlinux-2021-08-15T04:05:02        Sun, 2021-08-15 04:05:02 [563cd134a1867d786c89f10146c0d4d5b1db4a5be9b7e117fcbc10ff13cfd929]
archlinux-2021-08-16T04:05:01        Mon, 2021-08-16 04:05:03 [f82e9400e968cebaf40d04affc4c93a9ba16fb5c1a2b8f00abfdf5f42ee68f8c]
archlinux-2021-08-17T04:05:02        Tue, 2021-08-17 04:05:03 [30aba82f7e7a68de14d7c0d2bbff321526c5f5f6aafdbc91506260b4bfd680eb]
archlinux-2021-08-18T04:05:02        Wed, 2021-08-18 04:05:03 [8c17eb15891691062ae006c04562ce0309589b6a11788882839429d13afd3f55]
archlinux-2021-08-19T04:05:01        Thu, 2021-08-19 04:05:02 [e3448c03c7328912d9626bcb32474e38d2962c88825fa93a0d92ff161daa012c]
archlinux-2021-08-20T04:05:02        Fri, 2021-08-20 04:05:03 [cd7eb0024007eafd6f6bc601d4a20b545ba9603d69035781e39c41297a06ec70]
archlinux-2021-08-21T04:05:01        Sat, 2021-08-21 04:05:01 [434589f3b1ff983d52210345a8114e6660ffd0fea4db22daed8881c5b42600a1]
archlinux-2021-08-22T04:05:02        Sun, 2021-08-22 04:05:03 [a8e592fbced7fb4ea874d050c0075bb595ab06353b52afa6596e541e0c14ee4d]
```

## Resources
https://nixlab.org/blog/backup-kvm-virtual-machines  
https://www.ludovicocaldara.net/dba/bash-tips-4-use-logging-levels/  
https://borgbackup.readthedocs.io/en/1.1.16/quickstart.html
