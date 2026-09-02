# Deploying to Hetzner behind Cloudflare

Target: a Hetzner Cloud server in Helsinki, with Cloudflare proxying
`restai.ee`. The origin is firewalled so that only Cloudflare can reach it.

Nothing in this document has been run yet. It is the deployment procedure, to
be executed when you are ready.

## 1. Server

A CX22 (2 vCPU, 4 GB) is comfortable. The stack idles well under 1 GB.

Ubuntu 24.04 LTS. Create the server with your SSH key, and do not enable
password authentication.

```bash
ssh root@<server-ip>
adduser --disabled-password --gecos "" restai
usermod -aG sudo restai
rsync --archive --chown=restai:restai ~/.ssh /home/restai
```

Harden SSH in `/etc/ssh/sshd_config`:

```
PermitRootLogin no
PasswordAuthentication no
KbdInteractiveAuthentication no
```

```bash
systemctl restart ssh
```

Install Docker from the official repository, not the Ubuntu package:

```bash
curl -fsSL https://get.docker.com | sh
usermod -aG docker restai
```

## 2. DNS and Cloudflare

Point the `restai.ee` nameservers at Cloudflare, which you will have been given
when adding the domain. `.ee` domains are managed through your registrar's
control panel.

Then in Cloudflare:

| Setting | Value |
|---|---|
| DNS record | `A` for `restai.ee` to your server IP, **Proxied** (orange cloud) |
| DNS record | `CNAME` for `www` to `restai.ee`, Proxied |
| SSL/TLS mode | **Full (strict)** |
| Always Use HTTPS | On |
| Minimum TLS | 1.2 |

Proxied means visitors never learn your origin IP, and Cloudflare absorbs
denial of service traffic before it reaches Helsinki.

## 3. Origin certificate

Generate a Cloudflare Origin CA certificate: SSL/TLS, then Origin Server, then
Create Certificate. It is valid for 15 years, so there is no ACME renewal that
can quietly fail.

Save the certificate and key on the server as `caddy/cloudflare-origin.pem` and
`caddy/cloudflare-origin.key`. Both are gitignored.

```bash
chmod 600 caddy/cloudflare-origin.key
```

**Full (strict) matters.** Without it Cloudflare would accept any certificate
from the origin, including one an attacker presents, which defeats the point.

## 4. Firewall

This is the step that makes the origin genuinely private. Use the Hetzner Cloud
Firewall, applied at their network edge rather than on the host.

| Direction | Port | Source |
|---|---|---|
| Inbound | 22 | your own IP only |
| Inbound | 80, 443 | **Cloudflare IP ranges only** |
| Outbound | all | allow |

Cloudflare publishes its ranges at https://www.cloudflare.com/ips/ and they
change. Keep them current automatically:

```bash
pipx install cf-ips-to-hcloud-fw
# Then a daily cron job with a Hetzner API token scoped to firewall write.
```

Without this restriction, anyone who discovers the origin IP can bypass
Cloudflare entirely and hit the server directly.

## 5. Deploy

```bash
sudo mkdir -p /srv && sudo chown restai:restai /srv
cd /srv
git clone git@github.com:beekayverma/restai_blog.git
cd restai_blog
git submodule update --init --recursive

SITE_URL=https://restai.ee ./scripts/init-env.sh
```

Create `caddy/Caddyfile` for production, based on `Caddyfile.dev` but with the
real hostname and the origin certificate:

```
restai.ee, www.restai.ee {
	tls /etc/caddy/cloudflare-origin.pem /etc/caddy/cloudflare-origin.key
	# the rest is identical to Caddyfile.dev
}
```

Mount the certificate and use port 443 in the compose file, then:

```bash
make up
./scripts/setup-list.sh
make build
make test
```

## 6. After deploying, verify

```bash
curl -I https://restai.ee/                    # 200, security headers present
curl -o /dev/null -w '%{http_code}\n' https://restai.ee/admin   # must be 404
curl -I http://<origin-ip>/                   # must time out, not respond
```

The third check is the important one. If the origin answers directly, the
firewall rule is not doing its job.

Also confirm the built site still loads nothing third party:

```bash
curl -s https://restai.ee/ | grep -oE 'https?://[^"]+' | grep -v restai.ee
```

That should return nothing.

## 7. Backups off the server

`make backup` writes locally, which does not survive losing the server. Pull
them somewhere else:

```bash
rsync -az restai@restai.ee:/srv/restai_blog/backups/ ~/restai-backups/
```

Archives contain subscriber email addresses. Treat them as personal data under
the GDPR: encrypt at rest, and keep them only as long as you need them.

## Remaining considerations

- **Email.** Single opt-in needs no relay. Before your first campaign, add an
  SMTP relay and switch to double opt-in.
- **Monitoring.** Nothing is configured. An uptime check against `/` and an
  alert on failed backups would be the sensible minimum.
- **Updates.** Unattended upgrades for the OS, and a scheduled reminder to bump
  the pinned image tags.
