# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Hugo-based static blog for the ESR Labs Android Team. The blog covers Android Open Source Project (AOSP), Android Automotive OS (AAOS), and automotive infotainment development topics.

- **Framework**: Hugo v0.115.1 (extended with Dart Sass)
- **Theme**: hugo-PaperMod-7.0
- **Hosting**: GitHub Pages at https://esrlabs.github.io/android-team/

## Common Commands

### Development
```bash
hugo server                    # Start local dev server at http://localhost:1313/
hugo new posts/<post-name>.md  # Create new blog post from template
```

### Build
```bash
hugo --gc --minify --baseURL "https://esrlabs.github.io/android-team/"
```

### Team Collage
```bash
./create_collage.sh  # Regenerate team photo collage (requires ImageMagick)
```

## Architecture

```
content/              # Markdown blog posts and pages
├── _index.md         # Homepage content
└── posts/            # Blog articles

static/               # Static assets (images, fonts, favicon)
├── team-photos/      # Source photos for collage
└── team.png          # Generated team collage

themes/hugo-PaperMod-7.0/  # Theme (git submodule)

config.toml           # Hugo site configuration
```

## Deployment

Automated via GitHub Actions (`.github/workflows/hugo.yaml`). Push to `main` branch triggers build and deploy to GitHub Pages. Manual deployment available via workflow_dispatch.

## Content Guidelines

- Posts use YAML frontmatter with `title`, `date`, and `draft` fields
- Unsafe HTML is enabled in markdown rendering
- Images for posts go in `static/` or within `content/posts/<post-name>/`
