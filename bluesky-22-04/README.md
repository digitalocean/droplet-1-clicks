# BlueSky 1-Click Droplet Packer Build template

*We don't recommend to change order of this flow to make your bluesky PDS working*

## BlueSky configuration instructions:

* First for all domain or subdomain is required. Do not use too long, handle (username + hostname) can't be longer than 30 symbols, username can't be shorter than 3 symbols.
* Select bluesky app in [DigitalOcean marketplace](https://marketplace.digitalocean.com/), created droplet from it. It's ok to try smallest one droplet.
* Waiting for droplet creation.
* After droplet is created, copy its IP address from droplet page.
* Configure your DNS for wildcard using IP from previous step, [docs](https://docs.digitalocean.com/glossary/wildcard-record/). Without wildcard bluesky handle won't work.
* Join [AT Protocol PDS Admins Discord](https://discord.gg/UWS6FFdhMe) and register the hostname of your PDS. After ticket is closed and you see "You've been Federated :)", you can continue. This step takes about a day.
* SSH to droplet and finish installation process. Use your domain/subdomain as public DNS address, create account as PDS hostname with username as prefix (for example if your PDS hostname is `bsky.mydomain.com`, you prefer `scott` as username, enter as handle `scott.bsky.mydomain.com`). Save output in secure place, password willn't be shown anymore, you can just reset it using `pdsadmin`.
* After installation is complete you can use your handle. Go to [bsky.app](https://bsky.app/), select "Sign in", select Custom as Hosting provider and enter your handle as Server address. Enter email and password for just created account. 

## Useful links

* [About BlueSky](https://bsky.social/about)
* [The AT Protocol](https://atproto.com/)
* [PDS](https://docs.bsky.app/docs/advanced-guides/entryway)
* [Bluesky social PDS ReadMe](https://github.com/bluesky-social/pds)
* [Debug your handle](https://bsky-debug.app/handle)
* [Check your handle in crawler response](https://morel.us-east.host.bsky.network/xrpc/com.atproto.identity.resolveHandle?handle=YOUR_HANDLE)
