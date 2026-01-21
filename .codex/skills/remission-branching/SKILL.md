---
name: remission-branching
description: "Enforces Remission branching rules: always branch from synced origin/develop, never from master/main. Use for any request that creates or switches to a new feature/bugfix branch."
---

# Remission Branching

## Overview

This skill provides a safe, repeatable workflow for creating branches in Remission.
It ensures new work always branches from an up-to-date `develop` and never from `master`/`main`.

## Workflow

Use this workflow whenever the user asks to create a branch, start a task on a new branch, or troubleshoot branching.

### 1. Pre-checks

Run from repo root:
```bash
git status -sb
git branch --show-current
```
If there are uncommitted changes, confirm with the user how to proceed before switching branches.

### 2. Sync develop with origin

Always switch to `develop` and fast-forward from `origin/develop`:
```bash
git checkout develop
git fetch origin
git pull --ff-only origin develop
```
If fast-forward fails, stop and ask the user how to resolve the divergence. Do not reset or rebase without explicit approval.

### 3. Create the new branch

Create the branch from synced `develop`:
```bash
git checkout -b <branch-name>
```
Confirm the branch name with the user if not provided.

## Rules

- Never branch from `master` or `main`.
- Always branch from `develop` after syncing with `origin/develop`.
- Never use destructive commands (`git reset --hard`, forced checkouts) unless explicitly requested.
