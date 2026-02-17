# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Development Commands

```bash
# Install dependencies
npm install

# Local development server (preview at http://localhost:3000)
npm run dev

# Check for broken links in documentation
npm run broken-links

# Update Mintlify CLI to latest version
mint update
```

## Project Overview

This is a **Mintlify documentation site for OpenMetadata** with a multi-version architecture supporting three parallel version folders: `v1.10.x/`, `v1.11.x/`, and `v1.12.x-SNAPSHOT/`. Each version is self-contained with identical folder structures but version-specific content.

## Architecture

### Version Structure

Each version folder (`v1.10.x/`, `v1.11.x/`, `v1.12.x-SNAPSHOT/`) contains:
- `connectors/` - Database, messaging, pipeline, and other service connectors
- `deployment/` - Bare metal, Docker, Kubernetes deployment guides
- `quick-start/` - Getting started guides and sandbox setup
- `how-to-guides/` - Feature-specific user guides
- `features/` - Platform feature documentation
- `main-concepts/` - Core architectural concepts
- `sdk/` - SDK documentation and API guides
- `releases/` - Release notes and changelogs
- `api-reference/` - API endpoint documentation
- `developers/` - Developer contribution guides

### Navigation Configuration

**`docs.json`** (~509KB) is the single source of truth for site navigation. Structure hierarchy:
```
versions → tabs → groups → pages
```

Pages are referenced as `"v1.11.x/path/to/file"` (without `.mdx` extension).

### Reusable Content System

**`snippets/`** directory contains shared components and content:
- `snippets/components/` - React components (JSX files)
  - `ConnectorDetailsHeader.jsx` - Connector page headers with feature badges
  - `MetadataIngestionUi.jsx` - Metadata ingestion UI component
  - `CodePreview.jsx` - Code preview component
- `snippets/connectors/` - Cross-version connector snippets (MDX)
- `snippets/deployment/` - Cross-version deployment snippets (MDX)
- `snippets/how-to-guides/` - Cross-version guide snippets (MDX)
- `snippets/v1.11.x/` - Version-specific snippets for v1.11.x
- `snippets/v1.10.x/` - Version-specific snippets for v1.10.x
- `snippets/v1.12.x-SNAPSHOT/` - Version-specific snippets for v1.12.x-SNAPSHOT

### Asset Organization

- **Images**: `public/images/` organized by category (connectors, deployment, features, etc.)
- **API Specs**: `api-reference/openapi.json` for API reference generation
- Images are NOT duplicated per version; shared across all versions

## MDX File Patterns

### Required Frontmatter

```yaml
---
title: "Human-readable title | Optional subtitle"
description: "SEO-friendly description"
sidebarTitle: "Shorter sidebar title"  # Optional, use when filename is unclear
---
```

### Import Patterns (Always Absolute Paths)

```jsx
// React components
import { ConnectorDetailsHeader } from '/snippets/components/ConnectorDetailsHeader/ConnectorDetailsHeader.jsx'

// Cross-version snippets (shared across all versions)
import TestConnection from '/snippets/connectors/test-connection.mdx'

// Version-specific snippets
import Related from '/snippets/v1.11.x/connectors/database/related.mdx'
```

**CRITICAL**: All imports use absolute paths starting with `/snippets/` or `/public/`, never relative paths.

### Common Mintlify Components

- `<Steps>` / `<Step title="">` - Sequential step-by-step guides
- `<Tabs>` / `<Tab title="" icon="">` - Tabbed content organization
- `<Card>` / `<CardGroup cols={2}>` - Navigation and feature cards
- `<Note>`, `<Tip>`, `<Warning>` - Callout blocks for important information

### Image References

```jsx
// Always use absolute paths from workspace root
<img src="/public/images/connectors/mysql.webp" alt="MySQL" />
```

Prefer `.webp` format for connector logos and images.

## Workflow Patterns

### Adding New Content

1. **Determine target version(s)** - Does this apply to v1.10.x, v1.11.x, v1.12.x-SNAPSHOT, or all?
2. **Check `snippets/` for reusable content** - Don't duplicate if snippet already exists
3. **Create MDX file** with proper frontmatter in appropriate version folder
4. **Use absolute paths** for all imports (`/snippets/`, `/public/`)
5. **Update `docs.json`** navigation to add page to appropriate tab/group

### Editing Existing Content

1. **Consider cross-version impact** - Does change apply to all versions or just one?
2. **Preserve frontmatter structure** - Keep existing metadata format
3. **Maintain Mintlify component patterns** - Follow conventions from similar pages
4. **Use version-specific snippets** when content differs between versions

### Adding New Connectors

1. Create folder: `v1.11.x/connectors/{category}/{connector-name}/`
2. Add overview MDX with `ConnectorDetailsHeader` component showing available/unavailable features
3. Add implementation pages (setup, configuration, troubleshooting)
4. Import shared snippets from `snippets/connectors/` for common content
5. Add connector logo to `public/images/connectors/` (prefer `.webp` format)
6. Update navigation in `docs.json` under appropriate connector category group

### File Naming Conventions

- Use kebab-case: `local-docker-deployment.mdx`, `database-service-setup.mdx`
- Overview pages: `index.mdx` or descriptive name like `adls-datalake.mdx`
- Use `sidebarTitle` in frontmatter when filename is too technical or unclear

## Deployment

Changes are automatically deployed to production via Mintlify GitHub App integration when pushed to the default branch. Configure integration at [Mintlify Dashboard](https://dashboard.mintlify.com/settings/organization/github-app).

## Troubleshooting

- **Dev environment not running**: Run `mint update` to ensure latest CLI version
- **Page loads as 404**: Ensure running in folder with valid `docs.json` and page path matches docs.json reference
- **Broken links**: Run `npm run broken-links` to identify and fix broken internal/external links
