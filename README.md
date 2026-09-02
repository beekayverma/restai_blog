# REST AI

**Responsible, Ethical, Safe and Trustworthy AI.**

The source for [restai.ee](https://restai.ee), an initiative for awareness,
education and support in AI governance, risk, compliance and security.

AI GRCS is hard to break into. The regulations are new, the standards sit behind
paywalls, and most published material is either vendor marketing or legal
commentary written for lawyers. This site is an attempt to close some of that
gap, particularly for people starting out.

## Quickstart

Requires Docker and Docker Compose. Nothing else: Hugo, Node and PostgreSQL all
run in containers and are never installed on the host.

```bash
git clone git@github.com:beekayverma/restai_blog.git
cd restai_blog
git submodule update --init --recursive   # themes are pinned submodules
make init                                 # generate .env, start stack, build
```

Then open http://localhost:8080.

`make init` generates `.env` with random secrets, starts PostgreSQL, Listmonk
and Caddy, creates the subscriber list, and builds the site. To read the
Listmonk admin password afterwards:

```bash
grep LISTMONK_ADMIN_PASSWORD .env
```

## Commands

```
make help      show all targets
make up        start postgres, listmonk and caddy
make build     build the site with the active theme
make ab        build every candidate theme and serve side by side
make test      run the full acceptance suite
make backup    back up the subscriber database
make down      stop the stack, keeping data
```

## Stack

| Component | Role | License |
|---|---|---|
| [Hugo](https://gohugo.io) 0.165.0 | Static site generator | Apache-2.0 |
| [PostgreSQL](https://www.postgresql.org) 16 | The only database | PostgreSQL |
| [Listmonk](https://listmonk.app) 6.2.0 | Subscribers and newsletters | AGPL-3.0 |
| [Caddy](https://caddyserver.com) 2.11.4 | TLS and reverse proxy | Apache-2.0 |

**Why static.** The public site is plain files. There is no database behind it,
no admin panel to log into and no application server to exploit. The only
stateful component is the subscriber list, and PostgreSQL is the sole database
in the project by requirement.

**Why not Ghost.** Ghost supports MySQL 8 exclusively and
[dropped PostgreSQL](https://ghost.org/changelog/dropping-support-for-postgresql/)
before 1.0, so it could not meet the Postgres requirement.

## Layout

```
site/              Hugo project
  content/         Home, About, and blog posts in markdown
  layouts/         our own subscribe shortcode. No theme overrides remain
  config/themes/   one config overlay per candidate theme
  themes/          pinned submodules, left unmodified
compose/           docker-compose stack
caddy/             reverse proxy config
scripts/           build, backup, restore, style checks, setup
tests/             acceptance suite
docs/              runbook, deployment, writing guide, theme comparison
legacy/            the original single page mockup, kept for reference
```

## Writing a post

```bash
docker run --rm -v "$PWD/site:/src" -w /src \
  hugomods/hugo:debian-node-git-0.165.0 hugo new content blog/my-post.md
```

Edit it, set `draft: false`, then `make build`. Full details in
[docs/WRITING.md](docs/WRITING.md).

Two house rules, both enforced by `make test`:

- **No em dashes.** Use commas, colons or a full stop.
- **No secrets in tracked files.** `.env` is gitignored and generated locally.

## Themes

**Congo** is the active theme, chosen by comparing real builds of this site
rather than demo content. Blowfish stays installed as the alternate.

```bash
make ab      # builds each candidate and serves them side by side
make ab-stop
echo blowfish > .active-theme && make build   # switch
```

The evidence behind the decision, and every theme that was rejected with the
reason, is recorded in [docs/THEMES.md](docs/THEMES.md).

Themes are vendored as pinned submodules and left **unmodified**. Every colour,
font and spacing value comes from the theme author.

## Privacy

The built site loads **no third party resources**: no external fonts, no
analytics, no advertising, no tracking pixels, no CDN. This is verified by the
acceptance suite rather than asserted. Subscriber data lives in PostgreSQL on
your own server and is never passed to a third party processor.

## Testing

```bash
make test
```

Twenty two checks covering style, build, content structure, post ordering
verified from RSS dates, the running services, an end to end subscribe that
asserts a real row lands in PostgreSQL, security headers, that the Listmonk
admin panel is not publicly reachable, and a backup and restore round trip.

## Documentation

| Document | Covers |
|---|---|
| [docs/WRITING.md](docs/WRITING.md) | Writing and publishing posts |
| [docs/RUNBOOK.md](docs/RUNBOOK.md) | Operating the stack day to day |
| [docs/DEPLOY-HETZNER.md](docs/DEPLOY-HETZNER.md) | Deploying to Hetzner behind Cloudflare |
| [docs/THEMES.md](docs/THEMES.md) | Theme evidence and the A/B comparison |

## Contact

Bhupender Verma, Tallinn, Estonia.
[LinkedIn](https://www.linkedin.com/in/bhupender-v-042a2450/)
