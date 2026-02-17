# Project Guidelines

## Architecture

This is a **Mintlify documentation site** for OpenMetadata with three parallel version folders (`v1.10.x/`, `v1.11.x/`, `v1.12.x-SNAPSHOT/`). Each version is self-contained with identical folder structures but different content.

**Navigation:** [docs.json](../docs.json) is the single source of truth (~8686 lines). Structure: `versions` → `tabs` → `groups` → `pages`. Pages reference files as `"v1.11.x/path/to/file"` without `.mdx` extension.

**Content categories:** connectors, deployment, quick-start, how-to-guides, features, main-concepts, sdk, releases, api-reference.

## Code Style

### MDX Frontmatter
```yaml
---
title: "Human-readable title | Optional subtitle"
description: "SEO-friendly description"
sidebarTitle: "Shorter sidebar title"  # Optional
---
```

### Import Patterns (Always Absolute Paths)
```jsx
// React components
import { ConnectorDetailsHeader } from '/snippets/components/ConnectorDetailsHeader/ConnectorDetailsHeader.jsx'

// Generic snippets (shared across versions)
import TestConnection from '/snippets/connectors/test-connection.mdx'

// Version-specific snippets
import FeatureSnippet from '/snippets/v1.11.x/features/specific-feature.mdx'
```

### Common Mintlify Components
- `<Steps>` / `<Step title="">` - Step-by-step guides (see [day-1/database-service-setup.mdx](../v1.11.x/quick-start/getting-started/day-1/database-service-setup.mdx))
- `<Tabs>` / `<Tab title="" icon="">` - Tabbed content
- `<Card>`, `<CardGroup cols={2}>` - Link cards
- `<Note>`, `<Tip>`, `<Warning>` - Callouts
- React components: `<ConnectorDetailsHeader>`, `<MetadataIngestionUi>`

### Image References
```jsx
// Always absolute paths from workspace root
<img src="/public/images/connectors/mysql.webp" alt="MySQL" />
```

## Build and Test

```bash
# Install dependencies
npm install

# Local development (preview at http://localhost:3000)
npm run dev

# Check for broken links
npm run broken-links

# Update Mintlify CLI
mint update
```

## Project Conventions

### Versioning Strategy
- **Editing existing content:** Check if changes apply to all versions or specific version only
- **New features:** Add to appropriate version folder(s), then update navigation in [docs.json](../docs.json)
- **Snippets:** Use generic snippets in [snippets/connectors](../snippets/connectors/) for cross-version content; use [snippets/v1.11.x](../snippets/v1.11.x/) for version-specific

### Adding New Connectors
1. Create folder: `v1.11.x/connectors/{category}/{connector-name}/`
2. Add `index.mdx` with `ConnectorDetailsHeader` component (example: [v1.11.x/connectors/database/mysql/index.mdx](../v1.11.x/connectors/database/mysql/index.mdx))
3. Add implementation pages (`yaml.mdx`, `troubleshooting.mdx`, etc.)
4. Import shared snippets from [snippets/connectors](../snippets/connectors/)
5. Add connector logo to [public/images/connectors](../public/images/connectors/) (prefer `.webp`)
6. Update navigation in [docs.json](../docs.json) under appropriate tab/group

### File Naming
- Kebab-case: `local-docker-deployment.mdx`, `database-service-setup.mdx`
- Overview pages: `index.mdx`
- Use descriptive `sidebarTitle` in frontmatter if filename is unclear

### Reusable Components Location
- React components: [snippets/components/](../snippets/components/)
- Cross-version MDX snippets: [snippets/connectors/](../snippets/connectors/), [snippets/deployment/](../snippets/deployment/)
- Version-specific snippets: [snippets/v1.11.x/](../snippets/v1.11.x/), etc.

### Asset Organization
Images in [public/images/](../public/images/) organized by category (connectors, deployment, features, etc.). Not duplicated per version.

## Integration Points

- **GitHub App:** Auto-deploys from default branch via [Mintlify Dashboard](https://dashboard.mintlify.com/)
- **External links:** Navbar links to Slack community, blog, and Collate free tier
- **OpenAPI:** API reference uses [api-reference/openapi.json](../api-reference/openapi.json)

## Key Patterns

### When Creating Content
1. Determine target version(s)
2. Check [snippets/](../snippets/) for reusable content before writing new
3. Use absolute paths for all imports (`/snippets/`, `/public/`)
4. Add page to navigation in [docs.json](../docs.json)

### When Editing Content
1. Consider if change applies across v1.10.x, v1.11.x, v1.12.x-SNAPSHOT
2. Preserve existing frontmatter structure
3. Maintain Mintlify component patterns from similar pages
