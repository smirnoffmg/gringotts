# Project Context

## Overview

This appears to be a system installer or provisioning project, likely focused on automating OS installation (specifically Debian-based systems). The user base is likely system administrators or DevOps engineers setting up automated deployments.

## Tech Stack

- **Debian preseed** – automated Debian OS installation configuration
- **Shell/scripting** – likely used for installer automation (inferred from context)
- **Documentation** – markdown-based (`CLAUDE.md`, `todo.md`)
- Build/tooling details are minimal given the early-stage commit history

## Project Structure

- **`doc/`** – project documentation
- **`installer/`** – core installer assets, likely containing preseed configuration files and related scripts
- **`CLAUDE.md`** – project guidance file (likely for AI-assisted development context)
- **`todo.md`** – active task tracking

## Recent Activity

The project is in very early stages with only 3 commits. Active development is focused on Debian 13 preseed configuration, as indicated by the `[wip]` (work-in-progress) commit targeting that specific release. The addition of `todo.md` suggests the developer is planning upcoming features or tracking known gaps.

## Testing & CI

- **No test framework** identified
- **No CI configuration** detected (no `.github/`, `.gitlab-ci.yml`, or similar)
- **No coverage tooling** present
- Project is pre-CI stage; testing is likely manual at this time
