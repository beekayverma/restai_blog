# Themes: the decision and the evidence

**Decision: Congo.** Set in `.active-theme`, chosen 2026-09-02.

All figures come from the GitHub API, queried 2026-09-02. The "best Hugo themes
of 2026" articles that dominate search results are SEO and affiliate content and
were not used as evidence for anything here.

## Why Congo

The A/B was run properly: identical content, identical base config, one theme
each, compared as real builds of this site rather than as somebody else's demo.

| Theme | Homepage words | Lists posts | Subscribe form | Renders your prose |
|---|---|---|---|---|
| **Congo** | **401** | yes | yes | yes |
| Blowfish | 415 | yes | yes | yes |
| hugo-blog-awesome | 50 | yes | no | no |
| Hugoplate | 48 | no | no | no |

Congo and Blowfish were effectively tied on completeness. Congo won on weight
and simplicity: 256K of output against Blowfish's 500K, and fewer moving parts
to maintain. Both are MIT, actively maintained, and emit zero third party hosts
with no intervention.

Blowfish remains installed as the alternate. To switch:

```bash
echo blowfish > .active-theme && make build && make test
```

## Shortlist as verified

| Theme | Stars | License | Last push | Issues | Output |
|---|---|---|---|---|---|
| Congo | 1,649 | MIT | 2026-08-01 | 22 | 256K |
| Blowfish | 2,889 | MIT | 2026-08-30 | 5 | 500K |
| hugo-blog-awesome | 812 | MIT | 2026-08-29 | 8 | 380K |

## Why Hugoplate was dropped

It was the initial preference on looks, was made to build, and was then rejected
on evidence. Worth recording, because the reasons generalise.

**It is a marketing template, not a blog theme.** Its homepage is built from
front matter params (`banner`, `features`), never from `content/_index.md`. With
hero images and product copy stripped out, its homepage rendered 48 words: a
heading, one sentence and a button. The demo looked good because it was full of
marketing content this site does not have.

**It is a starter template on Hugo Modules, not a self contained theme.**
Upstream imports 26 external modules and needs a Go toolchain to fetch them.

**Its templates shipped tracking that could not simply be switched off.**
`head.html`, `script.html` and `baseof.html` called `gtm.html`,
`gtm-noscript.html`, `adsense-script.html` and `cookie-consent.html` with no
config guard at the call site, so the theme would not build without the
advertising modules present.

**Its style partial opened third party connections on every page load.**
preconnect and dns-prefetch hints to `googletagmanager.com`,
`google-analytics.com`, `connect.facebook.net`, `platform.linkedin.com` and
`platform.twitter.com`. preconnect is not a passive hint: the browser performs
DNS resolution and a full TCP and TLS handshake to each host, disclosing the
visitor's IP address and the fact of the visit to Google and Meta even with no
tracking script running. It also injected Google Fonts from Google's CDN, which
transfers visitor IP addresses to a third country and has been found to infringe
the GDPR in EU case law.

All of this was worked around successfully, with no-op stub partials and a
style.html override, and verified to produce zero third party hosts. Those
workarounds have since been removed along with the theme, because carrying
overrides for an unused theme is a maintenance liability.

## Also rejected

| Theme | Stars | Reason |
|---|---|---|
| PaperMod | 13,875 | **Cannot build on current Hugo.** Hugo 0.146 made underscore prefixed layout directories reserved, breaking its `layouts/partials/templates/_funcs/` helper. Verified failing on 0.147.9, 0.157.0 and 0.165.0. Upstream's latest commit is documentation only. Popularity is not maintenance. |
| TailBliss | 413 | Vite and Tailwind 4 pipeline with a custom `install.js`. Does not fit a containerised theme swap without bespoke work. |
| Stack | 6,467 | GPL-3.0 rather than MIT, and 3 months stale. Copyleft would constrain future customisation. |
| Coder | 3,106 | 85 open issues. Maintenance backlog. |
| hextra | 2,331 | 107 open issues, documentation oriented rather than a blog theme. |
| Terminal, console | 2,800 / 675 | Terminal aesthetic undercuts credibility with a CISO and board audience. |
| hello-friend-ng | 1,549 | 9 months stale, 58 open issues, licence does not resolve to a recognised SPDX identifier. |
| Bento | 57 | Last push 2021-07-26. Dead. |
| hugo-serif, hugo-whisper | 487 / 273 | Both stale since 2024. |
| newsroom | 327 | Licence does not resolve to a recognised SPDX identifier. |

## Running the comparison again

```bash
make ab        # builds congo, blowfish and blog-awesome, serves on 8082 to 8084
make ab-stop
```

## Outstanding

- **hugo-blog-awesome**: home page title renders as "Home" rather than
  "REST AI", and it shows neither your prose nor the subscribe form on the home
  page. Only worth fixing if it ever becomes a serious candidate.
