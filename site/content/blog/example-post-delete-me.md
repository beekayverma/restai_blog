---
title: "Example post: formatting reference"
date: 2026-08-15T10:00:00+03:00
draft: false
summary: "A reference showing every formatting feature available when writing posts. Delete this before launch."
tags: ["meta"]
---

> **Delete this post before launch.** It exists so you can see how each
> formatting option renders, and so the blog has more than one entry while the
> site is being built. Remove `site/content/blog/example-post-delete-me.md` and
> rebuild.
>
> Note that shortcodes such as `{{%/* note */%}}` are theme specific. This site
> deliberately avoids them in content, so that the same posts render correctly
> under every theme in the A/B comparison.

## Headings

Use `##` for sections and `###` for subsections. Skip `#`, the page title
already occupies that level.

### A subsection

Text under a subsection.

## Text formatting

**Bold** for emphasis that matters, *italic* for terms being introduced, and
`inline code` for identifiers, file paths and clause references such as
`ISO/IEC 42001:2023 clause 6.1.2`.

Links look like [this](https://restai.ee/). Prefer descriptive link text over
"click here", both for readers using screen readers and for search engines.

## Lists

Unordered:

- First item
- Second item
  - A nested item
- Third item

Ordered, useful for procedures:

1. Establish the scope
2. Identify the risks
3. Select the controls
4. Document the decisions

## Quotes

> Quotes are useful for regulation text. Always attribute them and link the
> source, and quote only what you need.

## Code

Fenced blocks take a language for syntax highlighting:

```python
def residual_risk(likelihood: int, impact: int) -> int:
    """Residual risk on a 5x5 matrix, after controls."""
    return likelihood * impact
```

```bash
make build   # build the site
make test    # run the acceptance suite
```

## Tables

| Framework | Instrument | Status |
|---|---|---|
| EU AI Act | Regulation 2024/1689 | Phasing in |
| EU CRA | Regulation 2024/2847 | Phasing in |
| ISO/IEC 42001 | AI management system | Published 2023 |
| ISO/IEC 27001 | Information security | Published 2022 |

## Images

Put image files in `site/static/images/` and reference them from the site root:

```markdown
![Alt text that describes the image](/images/example.png)
```

Always write real alt text. It is an accessibility requirement, and for a site
about responsible technology it would be a poor look to skip it.

## Front matter

Every post starts with a block like this:

```yaml
---
title: "Your title"
date: 2026-09-01T09:00:00+03:00
draft: false
summary: "One or two sentences shown in the post list and in link previews."
tags: ["ai-act", "iso-42001"]
---
```

Set `draft: true` while writing. Drafts are excluded from builds, so they never
appear on the live site. The `summary` is what LinkedIn shows when someone
shares the post, so it is worth writing deliberately.

## A note on punctuation

This project does not use em dashes. Use commas, colons or a full stop instead.
`make test` fails the build if one appears, so it is caught before it ships
rather than after.

{{< subscribe >}}
