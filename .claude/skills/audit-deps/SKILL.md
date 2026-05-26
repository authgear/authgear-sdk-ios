---
description: Audit and update vulnerable dependencies. Checks iOS (SPM) and RubyGems for known vulnerabilities, upgrades safe ones, and summarizes what needs manual attention.
disable-model-invocation: true
context: fork
allowed-tools: Read Edit Write Bash WebSearch WebFetch Glob Grep
---

Audit all dependencies in this repository for known security vulnerabilities and upgrade them where safe. Follow these steps carefully and sequentially.

## Step 1: Check iOS (Swift Package Manager) Dependencies

Read `Package.swift` and identify all external dependencies in the `dependencies:` array.

- If the array is empty, note "No external SPM dependencies found" and skip to Step 2.
- If there are dependencies, for each one:
  1. Note the package name and current version requirement.
  2. Search the web for known CVEs or security advisories for that package.
  3. If vulnerable, determine the patched version and check its changelog for breaking changes.

## Step 2: Audit RubyGems

Run the following commands to refresh the advisory database and scan `Gemfile.lock`:

```
bundle exec bundler-audit update
bundle exec bundler-audit check
```

Parse the output and collect a list of all reported vulnerabilities, including:
- Gem name
- Current locked version (from `Gemfile.lock`)
- CVE/advisory ID
- Advisory title
- Patched version(s) listed in the advisory

If `bundle exec bundler-audit check` exits 0 (no vulnerabilities), note that and skip to Step 4.

## Step 3: Evaluate and Upgrade Each Vulnerable Gem

For each vulnerable gem found in Step 2:

1. **Determine the safe patched version**: use the patched version range from the advisory.
2. **Check for breaking changes**: search the web or fetch the gem's changelog/GitHub releases to check if upgrading from the current locked version to the patched version introduces breaking changes (e.g., removed APIs, changed method signatures, new required config).
3. **Classify**:
   - `safe`: patch or minor bump, no documented breaking changes
   - `breaking`: major bump or documented breaking changes

**For `safe` gems**: Run:
```
bundle update <gem_name>
```
If the current `Gemfile` constraint prevents upgrading to the safe version, update the version constraint in `Gemfile` first (keep it as permissive as the original intent allows), then run `bundle update <gem_name>`.

**For `breaking` gems**: Do not upgrade. Record the gem, current version, patched version, CVE, and a brief description of the breaking changes for the summary.

After all safe upgrades, re-run:
```
bundle exec bundler-audit check
```
to confirm those vulnerabilities are resolved.

## Step 4: Provide a Final Summary

Present the following summary to the user:

---

## Dependency Audit Summary

### iOS (SPM)
[Either "No external dependencies found" or a table of packages checked, their status, and any actions taken]

### RubyGems

#### Updated — Vulnerabilities Fixed
| Gem | Old Version | New Version | CVE / Advisory |
|-----|-------------|-------------|----------------|
| ... | ...         | ...         | ...            |

#### Not Updated — Breaking Changes Required
| Gem | Current | Patched | CVE / Advisory | Breaking Change Summary |
|-----|---------|---------|----------------|-------------------------|
| ... | ...     | ...     | ...            | ...                     |

#### No Vulnerabilities Found
[List if clean, or omit this section]

### Recommended Next Steps
For each gem that was NOT updated, provide:
- What the breaking change involves
- What migration effort would be needed (e.g., update config, rename methods)
- Whether it is low/medium/high effort to migrate

---

Ask the user how they want to proceed with the gems that have breaking changes.
