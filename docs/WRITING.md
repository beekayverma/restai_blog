# Writing and publishing

## Create a post

```bash
docker run --rm -v "$PWD/site:/src" -w /src \
  hugomods/hugo:debian-node-git-0.165.0 hugo new content blog/my-post.md
```

This uses `site/archetypes/default.md`, so the new file arrives with front
matter filled in, `draft: true`, and the subscribe form already at the bottom.

Or copy an existing post. Filenames become part of the URL, so keep them short
and lowercase with hyphens.

## Front matter

```yaml
---
title: "What the AI Act actually asks of you"
date: 2026-09-02T09:00:00+03:00
draft: false
summary: "One or two sentences. Shown in the post list and in LinkedIn previews."
tags: ["ai-act", "iso-42001"]
---
```

| Field | Notes |
|---|---|
| `title` | Appears as the page heading and in the browser tab |
| `date` | Controls ordering. Posts sort newest first |
| `draft` | `true` excludes it from builds entirely. Set `false` to publish |
| `summary` | **Write this deliberately.** It is what LinkedIn shows when someone shares the post, and LinkedIn is the main distribution channel |
| `tags` | Optional, lowercase with hyphens |

## Preview and publish

```bash
make build     # build with the active theme
make test      # style, build and content checks
```

Open http://localhost:8080. Once the stack is running, rebuilding is enough:
Caddy serves `site/public` directly, so no restart is needed.

## House rules

**No em dashes.** Use a comma, a colon or a full stop. `make test` fails the
build if one appears, so it is caught before it ships.

**No secrets in tracked files.** The same check scans for credentials.

**Write real alt text on images.** It is an accessibility requirement, and on a
site about responsible technology, skipping it would be a poor look.

```markdown
![A 5x5 risk matrix with residual risk plotted after controls](/images/matrix.png)
```

Images go in `site/static/images/` and are referenced from the site root.

## Avoid theme specific shortcodes

Do not use shortcodes that belong to a theme, such as `notice` or `button`.
Content is shared across every theme in the A/B comparison, and a theme
specific shortcode breaks the build under every other theme.

`{{< subscribe >}}` is safe: it is defined in `site/layouts/shortcodes/` and
belongs to this project, not to any theme.

## Before you launch

Delete the formatting reference post, which exists only as scaffolding:

```bash
rm site/content/blog/example-post-delete-me.md && make build
```

Fill in the placeholder block on the About page with your real credentials. It
is marked with an HTML comment in `site/content/about.md`. Newcomers trust
specifics: "led an ISO 42001 implementation across a 40 person engineering org"
carries far more weight than "experienced AI governance professional".
