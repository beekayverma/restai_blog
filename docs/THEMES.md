# Themes: candidates, evidence, and the A/B

All figures come from the GitHub API, queried 2026-09-02. The "best Hugo themes
of 2026" articles that dominate search results are SEO and affiliate content and
were not used as evidence for anything here.

## How to run the comparison

```bash
./scripts/ab-build.sh          # build all four, then serve
./scripts/ab-build.sh --stop   # shut the preview servers down
```

| Theme | Preview |
|---|---|
| Hugoplate | http://localhost:8081 |
| Congo | http://localhost:8082 |
| Blowfish | http://localhost:8083 |
| hugo-blog-awesome | http://localhost:8084 |

Each one renders the **same content** from the **same base config**. The only
variable is the theme, so what you are comparing is your own site, not somebody
else's demo content.

## The shortlist

| Theme | Stars | License | Last push | Issues | Build deps | Output size |
|---|---|---|---|---|---|---|
| Hugoplate | 1,587 | MIT | 2026-08-16 | 10 | npm, Hugo Modules | 784K |
| Congo | 1,649 | MIT | 2026-08-01 | 22 | npm | 240K |
| Blowfish | 2,889 | MIT | 2026-08-30 | 5 | npm | 504K |
| hugo-blog-awesome | 812 | MIT | 2026-08-29 | 8 | none | 380K |

## Rejected candidates

| Theme | Stars | Reason |
|---|---|---|
| PaperMod | 13,875 | **Cannot build on current Hugo.** Hugo 0.146 made underscore prefixed layout directories reserved, which breaks its `layouts/partials/templates/_funcs/` helper. Verified failing on 0.147.9, 0.157.0 and 0.165.0. Upstream's latest commit is documentation only, so no fix is pending. Popularity is not maintenance. |
| TailBliss | 413 | Vite plus Tailwind 4 pipeline with a custom `install.js`. Does not fit a containerised theme swap without bespoke work, and not worth it at this size. |
| Stack | 6,467 | GPL-3.0 rather than MIT, and 3 months stale. Copyleft would constrain future customisation. |
| Coder | 3,106 | 85 open issues. Maintenance backlog. |
| hextra | 2,331 | 107 open issues, and documentation oriented rather than a blog theme. |
| Terminal, console | 2,800 / 675 | Terminal aesthetic undercuts credibility with a CISO and board audience. |
| hello-friend-ng | 1,549 | 9 months stale, 58 open issues, licence does not resolve to a recognised SPDX identifier. |
| Bento | 57 | Last push 2021-07-26. Dead. |
| hugo-serif, hugo-whisper | 487 / 273 | Both stale since 2024. |
| newsroom | 327 | Licence does not resolve to a recognised SPDX identifier. |

## What it took to make Hugoplate safe to ship

Hugoplate is a **starter template built on Hugo Modules**, not a self contained
theme. Upstream imports 26 external modules and its templates call several of
them unconditionally. Getting it to meet the "no tracking" claim on the About
page required four deliberate interventions, all documented in place.

**1. Advertising and tag manager modules are absent, not merely disabled.**
`head.html`, `script.html` and `baseof.html` call `gtm.html`, `gtm-noscript.html`,
`adsense-script.html` and `cookie-consent.html` with no config guard at the call
site. The enable check lives inside each upstream module, so the theme will not
build unless something answers. Upstream answers by importing the advertising
modules and leaving them switched off.

Instead, `site/layouts/_partials/` provides four no-op stubs. Project layouts
take precedence over modules, so the calls resolve to files that render nothing,
and adsense, google-tag-manager and cookie-consent never enter the dependency
tree at all.

**2. Third party preconnects removed.** Upstream `essentials/style.html` opened
every page with preconnect and dns-prefetch hints to `googletagmanager.com`,
`google-analytics.com`, `connect.facebook.net`, `platform.linkedin.com`,
`platform.twitter.com` and `ajax.googleapis.com`.

preconnect is not passive. The browser performs DNS resolution and a full TCP
and TLS handshake to each host on every page load, disclosing the visitor's IP
address and the fact of the visit to Google and Meta even though no tracking
script runs. `site/layouts/_partials/essentials/style.html` overrides this,
keeping the upstream CSS pipeline byte for byte and removing only the third
party connections.

**3. Google Fonts no longer loaded from Google.** The same partial injected
fonts from `fonts.googleapis.com` at runtime. Serving Google Fonts from Google's
CDN transfers visitor IP addresses to a third country and has been found to
infringe the GDPR in EU case law. Typography now falls back to the stack in
`data/theme.json`. If you want the original typeface, self host the files under
`site/static` rather than restoring the CDN link.

**4. Modules vendored.** The 21 remaining modules are committed under
`site/_vendor` (1.7 MB) by `./scripts/vendor-modules.sh`. Builds are therefore
offline, reproducible and auditable, and the production build never needs a Go
toolchain or a network fetch from GitHub.

Verified result: zero third party hosts in the built output, and no tracking
keywords anywhere. Congo, Blowfish and blog-awesome emit zero third party hosts
without any of this work.

## Known issues to settle after you choose

- **Hugoplate**: its post template enables Facebook and X share buttons and
  **disables** LinkedIn. Backwards for you, since LinkedIn is your distribution
  channel. Fixing it means overriding `layouts/blog/single.html`, deferred until
  the theme is chosen so the work is not wasted.
- **hugo-blog-awesome**: home page title renders as "Home" rather than
  "REST AI". A config fix, not a theme defect.
- **Hugoplate**: `site/layouts/_partials/essentials/style.html` is a copy of an
  upstream template. Re-check it whenever the submodule is updated, since it can
  drift.

## Recording the decision

When you pick one, write the theme name into `.active-theme` and note here why,
so the choice is documented rather than remembered.

```bash
echo congo > .active-theme && ./scripts/build.sh
```
