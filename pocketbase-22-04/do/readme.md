## DO Auto Update files

The files here are used by the DigitalOcean Marketplace to automatically keep the PocketBase 1-click up to
date with the most recent release.  We run this script daily with a cron job and submit any new versions
to the marketplace.

0 0 * * * cd /opt/pocketbase-packer/do && sh update-pocketbase.sh

It works by querying the GitHub API and comparing the newest version to the currently offered version from
the DO marketplace, then submitting to the DO api if there is a new version.