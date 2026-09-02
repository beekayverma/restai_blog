# Where we left off

Last updated 2026-09-02.

## State: working and pushed

Everything is committed to `github.com/beekayverma/restai_blog` on `main`.
The acceptance suite is green at **24 of 24**.

- **Theme: Hugoplate**, set in `.active-theme`. Congo was trialled and reverted.
- Its homepage was rebuilt (`site/layouts-hugoplate/home.html`) because the
  stock one rendered 48 words. Now 455, with prose, recent posts and the
  subscribe form.
- Footer has LinkedIn, GitHub and RSS icons.
- Zero third party resources load, verified across HTML and CSS.

## Pick up here

1. **About page credentials.** `site/content/about.md` has a placeholder block
   marked with an HTML comment. It needs your real certifications, roles and
   career highlights. I will not invent them.
2. **Pagefind search.** Planned, not built. Client side, no server, no third
   party.
3. **Delete the scaffolding post** before launch:
   `rm site/content/blog/example-post-delete-me.md`
4. **Deploy.** Fully documented in `docs/DEPLOY-HETZNER.md`, never executed.
   Hetzner Helsinki, Cloudflare proxied, origin firewalled to Cloudflare ranges.

## Running it again

```bash
cd ~/Desktop/aigrc_blog
make up          # postgres, listmonk, caddy
make build       # rebuild after editing content
make test        # 24 checks
```

Site on http://localhost:8080. Listmonk admin is loopback only on :9000, and
its password is in `.env`.

The stack has `restart: unless-stopped`, so it comes back after a reboot. The
A/B preview servers do not; restart them with `make ab`.

## Two traps already hit, do not repeat

- **`.gitignore` anchoring.** An unanchored `data/` matched Hugo's `site/data/`
  and silently kept `social.json` out of the repo, which made the footer icons
  vanish on a fresh clone. Volume patterns are now anchored with a leading slash.
- **Third party checks must scan CSS, not just HTML.** Font Awesome pulled its
  webfonts from a CDN through a `url()` inside a stylesheet, invisible to an
  HTML only scan. Fonts are now self hosted and the check covers both.
