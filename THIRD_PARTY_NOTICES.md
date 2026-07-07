# Third Party Notices

This file records third-party source code that is copied, vendored or materially modified inside this repository.

At the time this file was created, no third-party source code has been copied into this repository for V4.0. Package dependencies should be tracked by their package manager files and package-level documentation. This file becomes mandatory when source code is copied into `third_party/` or any project package.

## Policy

When third-party source code is copied or vendored, add an entry with:

- Project name
- Upstream URL
- License
- Copied scope
- Local location
- Whether it was modified
- Modification summary
- Purpose in this project
- Review date

## Planned V4.0 Review Targets

| Project | Intended use | Copy status |
|---|---|---|
| Airtest | Python Sidecar dependency for visual automation and report ideas | Not copied |
| Pyxelator | Image target resolver, dependency preferred, small-module copy allowed after review | Not copied |
| Appium Inspector | Inspector product and protocol reference, no Electron UI copy | Not copied |
| appium-mcp | MCP-compatible tool model reference, no Node runtime copy | Not copied |

## Template

```text
Project:
Upstream:
License:
Copied scope:
Local location:
Modified:
Modification summary:
Purpose:
Review date:
```
