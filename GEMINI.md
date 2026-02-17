# GEMINI.md - OpenMetadata Documentation (Mintlify)

This directory contains the documentation for **OpenMetadata**, an open-source unified platform for data discovery, lineage, and governance. The documentation is built using [Mintlify](https://mintlify.com/).

## Project Overview

*   **Platform:** [Mintlify](https://mintlify.com/)
*   **Content Format:** [MDX](https://mdxjs.com/) (Markdown with JSX)
*   **Main Configuration:** `docs.json` - Defines navigation, versions, tabs, and site-wide settings.
*   **Version Management:** Supports multiple versions (e.g., `v1.10.x`, `v1.11.x`, `v1.12.x-SNAPSHOT`) each with its own directory and entry points.
*   **Key Directories:**
    *   `v1.x.x/`: Version-specific documentation content.
    *   `api-reference/`: API documentation, likely driven by OpenAPI (`openapi.json`).
    *   `essentials/`: Core documentation on using Mintlify features (navigation, markdown, code, etc.).
    *   `snippets/`: Reusable MDX components and content fragments.
    *   `public/` & `images/`: Static assets (icons, banners, screenshots).
    *   `logo/`: Brand identity assets.

## Building and Running

The project uses the Mintlify CLI (`mint`) for local development and validation.

### Prerequisites
- Node.js (v19 or higher recommended)
- Mintlify CLI installed globally: `npm i -g mint`

### Commands
- **Start Preview Server:** `npm run dev` or `mint dev`
  - Runs a local preview at `http://localhost:3000`.
- **Check for Broken Links:** `npm run broken-links` or `mint broken-links`
  - Validates all internal and external links in the documentation.
- **Update CLI:** `mint update`
  - Ensures you have the latest version of the Mintlify CLI.

## Development Conventions

### Content Management
- **Navigation:** All pages must be manually added to the `navigation` object in `docs.json` to appear in the sidebar.
- **MDX Features:** Extensive use of Mintlify components like `<AccordionGroup>`, `<Step>`, `<CardGroup>`, `<Tip>`, `<Note>`, and `<Info>`.
- **Snippets:** Use the `snippets/` directory for reusable content to adhere to DRY principles.
- **Images:** Prefer placing images in `public/images/` and referencing them with absolute paths (e.g., `/public/images/icon.svg`).

### Style and Behavior
- **Custom Styling:** Global styles are defined in `globals.css` and `style.css`.
- **Custom Logic:** `loader.js` contains a lightweight page transition/loading bar implementation.
- **Versioning:** When adding new content, ensure it is placed in the correct versioned directory and updated in the corresponding version section of `docs.json`.

## Key Files
- `docs.json`: The "source of truth" for site structure and metadata.
- `package.json`: Defines project dependencies (`mint`, `react`) and scripts.
- `development.mdx`: Internal guide for contributing to this documentation.
- `v1.11.x/index.mdx`: The main landing page for the v1.11.x documentation version.
