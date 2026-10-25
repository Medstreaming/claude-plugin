---
name: medstyle-presentation
description: 'Build a Medstreaming-branded slide deck (Slides artifact) with the house look: logo-derived navy/blue/yellow/green palette, Space Grotesk + DM Sans, four-colour stripe, outlined cards with offset shadows, the Medstreaming logo on every slide. Use whenever the user asks for a presentation, deck, slides or training/overview talk for Medstreaming, a plugin, a feature, a release or a task workflow, even if they do not mention branding or colours. Use when the user types /med:medstyle-presentation <topic>.'
argument-hint: '<topic or source document for the deck>'
---

# /med:medstyle-presentation <topic>

Builds a deck in the Slides artifact type, styled to match the Medstreaming logo. The look was approved by the team on the
"Med Task Workflow" deck; the finished slides are kept in `assets\slides\` as templates. **Copy their markup instead of
inventing a new style** - a deck that drifts from the template stops looking like Medstreaming.

If the user gave no topic, ask for it. If the content is thin, write concrete draft text with `[bracketed placeholders]`
for figures the user did not give. Never invent statistics, timings or quotes.

## 1. Start the artifact

1. Call the Artifact tool with `action: "quickstart"`, `intent: "slides"`, `design_systems: false`, then publish with the returned
   `type_url`, a `title`, and `auto_open: "after_first_write"`. Follow the returned type instructions for file layout
   (`project/deck.json` + `project/slides/<id>.html`, one `<section>` per file, inline styles from a closed subset).
2. Upload the logo once: `action: "publish"`, `url: <the new artifact>`, `asset: true`,
   `file_path: <this skill>\assets\medStreamingNewLogo.png`. The reply gives `/_blob/<id>`; use that url verbatim as `<img src>`.
   Every template contains the token `__LOGO_URL__` where it goes.

## 2. Design system

| Token | Value | Use |
|---|---|---|
| Navy | `#002F49` | dark slides, headings, card outlines |
| Blue | `#0097DC` | cover/closing panel, stripe, card shadows |
| Yellow | `#F5B800` | pill label, the "statement" slide background |
| Green | `#72BF44` | stripe, card shadows |
| Light bg | `#F4F8FB` | light slides |
| Card | `#FFFFFF`, 3px navy border, radius 12 | cards |
| Body text | `#3E5566` | paragraphs on light |
| Footer text | `#5A6E7E` | page footer on light |
| On-dark text | `#F4F8FB` / `#BFD4E2` | headings / body on navy |
| Dark card | `#0A4261`, accent text `#5CC4F0` | cards on navy |
| Label text on light | `#0072A8` blue, `#7A5C00` yellow, `#3C7A1C` green | small coloured labels (the raw brand colours are too light for text on `#F4F8FB`) |

Fonts (declare all three in `deck.json` `faces`, see `assets\deck.sample.json`): **Space Grotesk** 700 for headings,
**DM Sans** for body, **JetBrains Mono** for commands, file names and code. Type scale: 128/100 hero, 68 title, 36-40 card
title, 26-28 body, 24 labels and footer. Nothing under 24px.

The brand colours come from the logo (navy "streaming", blue "Med", and the yellow, green and blue flags). They are
approximate, estimated from the PNG; if the user supplies official hex values, change the table and the templates together.

## 3. Slide recipes (copy from `assets\slides\`)

| Template | Use for |
|---|---|
| `cover.html` | Slide 1: navy, blue right panel with `/med`, logo on a white badge top-left, install/command line at the bottom |
| `idea.html` | One bold statement on yellow, logo badge top-left |
| `problem.html` | Row of 3-4 outlined cards, each with a different shadow colour, plus one summary sentence |
| `commands.html` | 3x2 grid of cards: step label, mono command, one-line description |
| `redundancy.html` | Comparison table: navy header row, alternating white/`#E3EFF6` rows |
| `trail.html` | Dark mono panel (file tree or code) beside three short explanations |
| `gains.html` | 2x2 cards, short title + one sentence each |
| `guardrails.html` | Dark slide, 2x2 cards outlined in blue/yellow/green/light-blue |
| `install.html` | Mono command panel, then three small cards |
| `walkthrough.html` | Stacked rows: mono command left, outcome right |
| `close.html` | Navy with blue panel and `/med`, logo badge, call to action |

Rules every slide follows (they are what make the deck read as Medstreaming):

- **Light slides**: four stacked 24px-wide stripe segments down the left edge (navy, blue, yellow, green, 270px each), the logo
  pinned top-right (`left:1492px; top:28px; width:300px; height:90px; object-fit:contain`), a yellow pill label above a
  Space Grotesk title, footer `<name> · <n>` pinned at `bottom:64px`.
- **Dark and coloured slides**: the navy logo text disappears on dark, so put the logo on a white rounded badge
  (360x100 box with the 320x80 image inside). Use the four-segment 16px band along the bottom edge instead of the stripe.
- **Cards**: white, 3px navy border, 12px radius, `box-shadow: 8px 8px 0 <brand colour>`. Vary the shadow colour by meaning
  (for example plan = blue, build = yellow, review = green, test = navy), not at random.
- Pinned backdrops and logo go **first** in the section so flow content paints over them.
- One idea per slide; turn lists into cards, tables or a mono panel. Aim for 8-12 slides: cover, problem, idea, how it works,
  what changes, how to use it, safeguards or limits, install, example run, close.
- Keep speaker notes (plain text `<aside>`, last child) on every slide. Use `&lt;` and `&gt;` for angle brackets in text.
- Footer text is the deck name plus the slide number; renumber after adding or removing slides, and keep `order` in
  `deck.json` in sync with the files.

## 4. Build and publish

Write `project/deck.json` first (complete `order`, `sections`, the three `faces`, `createdOnFiles`), then the cover, and publish
those two together; then write the remaining slides three at a time and publish with the same `url` and `root`. Replace
`__LOGO_URL__` in every slide with the uploaded asset url. Do not render or screenshot unless the user asks.

Finish by giving the link and saying the artifact is private until the user shares it from the page's Share menu. State any
placeholders left for the user to fill.
