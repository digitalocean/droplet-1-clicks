# BlueSky 1-Click Droplet Packer Build template

*We recommend you don't change the order of this flow to make your BlueSky PDS work.*

## BlueSky configuration instructions:

* First and foremost, a domain or subdomain is required. Ensure it's not too long; the handle (username + hostname) should be no longer than 30 characters, with the username being at least 3 characters long.
* Select the BlueSky app in the [DigitalOcean marketplace](https://marketplace.digitalocean.com/), and create a droplet from it. It's ok to start with the smallest droplet size, but migrating to a bigger droplet will be a hard task (see the link in Useful links section).
* Wait for the droplet creation process to complete.
* Once the droplet is created, copy its IP address from the droplet page.
* Configure your DNS for wildcard usage by using the IP from the previous step. Refer to the [docs](https://docs.digitalocean.com/glossary/wildcard-record/). Without a wildcard, the BlueSky handle won't function correctly.
* Join the [AT Protocol PDS Admins Discord](https://discord.gg/UWS6FFdhMe) and register the hostname of your PDS. After the ticket is closed and you see "You've been Federated :)", you can proceed. This step typically takes about a day.
* SSH into the droplet to complete the installation process. Use your domain/subdomain as the public DNS address and create an account with the PDS hostname, with the username as a prefix. For instance, if your PDS hostname is `bsky.mydomain.com`, you prefer `scott` as the username, enter as handle: `scott.bsky.mydomain.com`. Save the output in a secure location; the password won't be displayed again, but you can reset it using `pdsadmin`.
* After installation is complete you can use your handle. For example, visit [bsky.app](https://bsky.app/), choose "Sign in," select Custom as the Hosting provider, and input your handle as the Server address. Enter the email and password for the newly created account.

## Useful links

* [About BlueSky](https://bsky.social/about)
* [The AT Protocol](https://atproto.com/)
* [PDS](https://docs.bsky.app/docs/advanced-guides/entryway)
* [Bluesky social PDS ReadMe](https://github.com/bluesky-social/pds)
* [PDS Migration](https://github.com/bluesky-social/pds/blob/main/ACCOUNT_MIGRATION.md)
* [Debug your handle](https://bsky-debug.app/handle)
* [Check your handle in crawler response](https://morel.us-east.host.bsky.network/xrpc/com.atproto.identity.resolveHandle?handle=YOUR_HANDLE)
