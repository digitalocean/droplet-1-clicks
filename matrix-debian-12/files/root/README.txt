

                  IT'S DANGEROUS TO GO ALONE! TAKE THIS.

                                  ⚔️


                      !Hello new Matrix operator!


Operating a Matrix server is relatively simple, but there are some things you
must know.


INSTALLATION AND MANAGEMENT
---------------------------
If you have not done so already, please run ./finish-setup - this script will
walk you through the end of your configuration. You may run the script multiple
times if you think you may have missed something.

There several scripts in your home directory - this is what they do.

/root/finish-setup:        finish your matrix installation
/root/new-user:            make a new matrix user
/root/reset-password:      reset the password of a matrix user
/root/upgrade-element:     upgrade element to the given version


UPGRADES
--------
It is recommended to upgrae synapse and element-web at least once a month.

Please watch out for security vulnerabilities: https://matrix.org/blog/category/security

Upgrading is very simple.

To upgrade Synapse:
    apt update
    apt upgrade

to upgrade Element:
    ./upgrade-element <version-number>


MODERATION
----------
Currently, moderation utilities are a bit lacking. Some are good, but they are
complicated to set up.

Initially, room admins can manage a room by kicking/banning individuals who are
problematic. If your community grows large enough, you may need something more
automated.

See https://github.com/matrix-org/mjolnir


CAPACITY PLANNING
-----------------
If your users wind up consuming a ton of disk space because they post dank memes
all day, you'll run out of storage space eventually. 

For small communities:
    I recommend attaching a larger volume to your droplet and mounting
    it at /var/lib/matrix-synapse/media

For large communities:
    I recommend migrating your media storage to an S3 compatible storage
    platform - like DigitalOcean Spaces.
    See https://github.com/matrix-org/synapse-s3-storage-provider for details
