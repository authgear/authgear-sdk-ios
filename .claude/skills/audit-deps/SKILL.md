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

If `bundle exec bundler-audit check` exits 0 (no vulnerabilities), note that and skip to Step 2a.

## Step 2a: Re-check Previously Ignored Advisories

If a `.bundler-audit.yml` file exists at the repo root with an `ignore:` list, each entry there was suppressed in a past run because it couldn't be resolved at the time (e.g. a transitive dependency pinned by another gem). Before moving on, check whether any of them can now be resolved:

1. Read `.bundler-audit.yml` and note each ignored advisory ID, along with the surrounding comment explaining why it was ignored (which gem it affects and what was blocking the fix).
2. Get the full, unfiltered vulnerability list by bypassing the ignore config:
   ```
   bundle exec bundler-audit check --config /tmp/nonexistent-bundler-audit.yml
   ```
   (Pointing `--config` at a path that doesn't exist makes bundler-audit skip the ignore list entirely — do not delete or rename the real `.bundler-audit.yml`.)
3. For each previously-ignored advisory ID:
   - If it no longer appears in the unfiltered output, it's already resolved — remove its entry from `.bundler-audit.yml` (and the file entirely if the ignore list becomes empty).
   - If it still appears, identify the gem it applies to and the blocking dependency noted in the comment (e.g. "jazzy pins sqlite3 to ~> 1.3"). Check whether that blocker has since changed:
     - Search the web / check the blocking gem's latest release and gemspec/changelog for whether its constraint on the vulnerable gem has relaxed enough to allow the patched version.
     - If it now allows the patch, treat this gem like any other vulnerable gem found in Step 2 and run it through Step 3's evaluate-and-upgrade flow. If the upgrade succeeds and `bundle exec bundler-audit check` no longer reports it, remove the corresponding entry from `.bundler-audit.yml`.
     - If the blocker is still in place, leave the ignore entry as-is and note it in the final summary under "Still Ignored — Blocked" so the user has current status without needing to dig through the file.

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

#### Still Ignored — Blocked
[List any advisories from `.bundler-audit.yml` that remain unresolved, the gem/dependency still blocking them, and what would need to change to unblock. Omit this section if `.bundler-audit.yml` has no ignore entries left, or doesn't exist.]

### Recommended Next Steps
For each gem that was NOT updated, provide:
- What the breaking change involves
- What migration effort would be needed (e.g., update config, rename methods)
- Whether it is low/medium/high effort to migrate

---

Ask the user how they want to proceed with the gems that have breaking changes.
