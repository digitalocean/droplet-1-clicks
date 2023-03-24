#
# This script is used to create a logical partition off a file and mount it.
# We do it to limit NFS access to a separate partition and also to a size.
#
# For creating a separate partition off a file on local root disk.
# 
# You do not need it for DO block volumes. Those are already mounted for you
# in /mnt folder.
#

# Create an empty file - blocksize (128MB) x 80 blocks = 10GB. You can adjust
# per your requirement and available disk
#
echo creating an empty file of size 10GB
dd if=/dev/zero of=/nfs-local-disk-do-not-delete.img bs=128M count=80
df -k /
ls -l /nfs-local-disk-do-not-delete.img 

# Create a file system in that file
echo "Now adding a file system"
mkfs -t ext4 /nfs-local-disk-do-not-delete.img 

# Create a folder where we can mount the filesystem
mkdir /mnt/local_nfs

# Mount the filesystem 
echo "mounting the file system"
mount -o loop,rw,sync /nfs-local-disk-do-not-delete.img /mnt/local_nfs

# The new partition is ready. Note that the whole filesystem 
# is a single file (/nfs-local-disk-do-not-delete.img) on the disk
echo "The local partition is ready. You can use it as NFS share. Remember to take the backup frequently."

# Change the ownership to nobody for NFS
sudo chown -R nobody:nogroup /mnt/local_nfs/
#sudo chmod 777 /mnt/local_nfs/

df -k /mnt/local_nfs/
