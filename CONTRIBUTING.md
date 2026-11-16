# Contributing

To keep this repository consistent and reliable, changes go through **Pull Requests** and follow the **Conventional Commits** specification.

---

## Table of Contents

1. [Code of Conduct](#1-code-of-conduct)
2. [Workflow](#2-workflow)
3. [Conventional Commits](#3-conventional-commits)
4. [Standards](#4-standards)

---

## 1. Code of Conduct

Review our [Code of Conduct](CODE_OF_CONDUCT.md). You must agree to its terms to contribute to this project.

---

## 2. Workflow

All changes are proposed via pull requests and reviewed before they're merged into `main`.

1. **Fork and branch**:
    - Create a branch off `main`:
      ```bash
      git checkout -b feature/add-cool-mod
      ```
    - Branch naming conventions:
        - `feature/<short-description>`: New mods, scripts or features
        - `bugfix/<short-description>`: Bug fixes
        - `chore/<short-description>`: Everything else (documentation, CI)
2. **Commit your changes**: Follow the [Conventional Commits](#3-conventional-commits) specification for all commit messages.
3. **Open a pull request**: Push your branch and open a PR targeting `main` using the [Pull Request Template](.github/pull_request_template.md).

Merging into `main` publishes the change: the downloads of every mod and script it touches are replaced automatically.

---

## 3. Conventional Commits

This repository uses **[Conventional Commits v1.0.0](https://www.conventionalcommits.org/)**.

### 3.1. Format

```text
<type>[optional scope]: <description>

[optional body]
```

Use the mod's or script's name as the scope, for example `fix(rave-barriers): …`.

### 3.2. Commit Types

| Type       | Description                                                  |
|:-----------|:-------------------------------------------------------------|
| `feat`     | A new mod or script, or a new feature in one                 |
| `fix`      | A bug fix                                                    |
| `perf`     | A change that improves performance                           |
| `refactor` | A change that neither fixes a bug nor adds a feature         |
| `style`    | Formatting only, with no change in behaviour                 |
| `docs`     | Documentation changes only                                   |
| `build`    | Changes to how fastfiles are built (zone lists, generators)  |
| `ci`       | Changes to the GitHub Actions workflows                      |
| `chore`    | Anything else that doesn't change a mod or script            |
| `revert`   | Reverts a previous commit                                    |

---

## 4. Standards

- **Scripts (GSC)**:
    - `snake_case` for functions and variables (`start_on_rave()`, `clear_on_empty()`).
    - Describe each function in a comment above it. Leave the code inside uncommented unless it's doing something weird.
    - Name a script `dev_<name>.gsc` while it's for testing only. Scripts with that prefix are never released.
- **Mods**:
    - Keep each mod in its own folder under `mods/`, laid out as iw7-mod loads it.
    - When a mod's assets change, rebuild its `mod.ff` and commit it with the source change.
    - Don't commit the `.dcache` files the game writes into a mod's folder.
- **Testing**: Load the mod or script in game before opening a pull request, and check the console log for errors.
