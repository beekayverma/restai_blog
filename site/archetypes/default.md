---
title: "{{ replace .Name "-" " " | title }}"
date: {{ .Date }}
draft: true
summary: "One or two sentences. This is what shows in the post list and in LinkedIn link previews, so write it deliberately."
tags: []
---

Write the post here.

Set `draft: false` when it is ready. Remember: no em dashes, `make test` will
catch them.

{{< subscribe >}}
