# Blog packages

This directory is for blog content that can be published to the **Microsoft TechCommunity Linux and Open Source Blog**.

## Packaging approach

TechCommunity-friendly authoring still starts with Markdown, but the repo should keep publishing assets next to the post source rather than treating a `.md` file as the entire deliverable.

Each blog package should include:

- `source/`: authoring copy in Markdown
- `publish/metadata.yml`: title, summary, tags, and submission notes
- `publish/social-copy.txt`: short launch copy for promotion
- `publish/image-manifest.csv`: image inventory and alt text
- `assets/`: screenshots, diagrams, and supporting visuals

## Current blog seed

- `opensearch/`: initial two-part blog package based on the direction of the existing OpenSearch drafts, rewritten for this repository and its AKS AVM focus
- `templates/`: reusable files for future workload blog packages

