# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

OpenMetadata documentation site built with [Mintlify](https://mintlify.com/docs). Multi-version docs for OpenMetadata (v1.10.x, v1.11.x, v1.12.x-SNAPSHOT). The default/current version is **v1.11.x** — unversioned URLs redirect there.

## Development Commands

```bash
npm i -g mint          # Install Mintlify CLI (requires Node.js >= 19)
mint dev               # Local preview at http://localhost:3000
mint dev --port 3333   # Custom port
mint broken-links      # Validate links across all pages
mint update            # Update CLI to latest version
```

Deployment is automatic: push to `main` → deployed via Mintlify GitHub app.

Commit messages: prefix with `Docs:` and include PR number — `Docs: Add release notes for 1.11.9 (#34)`

---

## Contributing Content

This section covers writing and editing documentation pages.

### Page Frontmatter

Every page starts with YAML frontmatter:

```yaml
---
title: "Page Title"
description: "SEO description"
sidebarTitle: "Short Nav Label"   # optional, for shorter sidebar text
mode: "wide"                      # optional, for full-width pages
---
```

### File Naming

- Kebab-case for files and directories (`auto-classification.mdx`)
- `.mdx` for pages with JSX/component imports, `.md` for pure markdown
- Images go in `/public/images/` organized by category

### Mintlify Components

Pages use MDX with built-in components: `<Steps>`, `<Step>`, `<CardGroup>`, `<Card>`, `<Tip>`, `<Info>`, `<Warning>`, `<Accordion>`, `<AccordionGroup>`, `<Tabs>`, `<Tab>`.

### Snippets (Shared Content)

Reusable content lives in `snippets/` and is imported via absolute paths:

```jsx
import TestConnection from '/snippets/connectors/test-connection.mdx'
import DataProfiler from '/snippets/v1.11.x/connectors/yaml/data-profiler.mdx'
```

There are **shared snippets** (`/snippets/connectors/`) and **version-specific snippets** (`/snippets/v1.11.x/connectors/`). Version-specific snippets override shared ones when content differs between versions.

### Connector Docs Pattern

Connector pages follow a consistent template:
1. Import shared snippets and `ConnectorDetailsHeader`
2. Render `<ConnectorDetailsHeader>` with features matrix
3. Requirements section
4. Metadata ingestion configuration
5. Optional: Query Usage, Lineage, Data Profiler, Data Quality, dbt
6. Troubleshooting

### Registering New Pages

New pages **must** be added to `docs.json` in the appropriate navigation section, or they won't appear in the sidebar.

---

## Changing the Site

This section covers the infrastructure: navigation, styling, components, and versioning.

### Navigation Configuration

All navigation is defined in `docs.json` (very large file, ~6k+ lines). It defines:
- Version tabs and page hierarchy per version
- Redirects from unversioned paths to v1.11.x
- Footer, navbar, SEO, and theme settings

### Versioned Content Structure

Each version is a self-contained directory with identical structure:

```
v1.11.x/
  index.mdx              # Homepage
  quick-start/            # Getting started
  deployment/             # Docker, Kubernetes, Bare Metal
  connectors/             # database/, dashboard/, pipeline/, storage/, etc.
  how-to-guides/          # Feature walkthroughs
  sdk/                    # Python/Java SDK
  developers/             # Contributing
  api-reference/          # REST API docs
```

### Custom React Components

Three JSX components in `snippets/components/`:

- `ConnectorDetailsHeader.jsx` — Feature support matrix for connectors (stage, available/unavailable features)
- `MetadataIngestionUi.jsx` — UI workflow screenshot sequences
- `CodePreview.jsx` — Side-by-side code/content panels

### Styling

- `globals.css` — CSS variables (colors, layout dimensions, fonts), Tailwind imports
- `style.css` — Custom component styling and overrides
- `loader.js` — Page loader animation
- Theme is `"aspen"`, primary color `#6938EF`
