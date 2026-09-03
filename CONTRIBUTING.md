## How to release a new version

Set the version once and reuse it in every command below:

```
VERSION=3.0.0
```

1. Make sure every change you want to ship is merged into `main`, then branch
   off it as `release/$VERSION`:
   ```
   git checkout main
   git pull origin main
   git checkout -b release/$VERSION
   ```
2. Add an entry to [`CHANGELOG.md`](./CHANGELOG.md) for the new version,
   following [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)
   conventions (`Added`/`Changed`/`Deprecated`/`Removed`/`Fixed`/`Security`).
   Call out any breaking change under its own `### Breaking` heading,
   including ones the compiler won't catch for consumers.
3. Pick the version following [Semantic Versioning](https://semver.org/) —
   this is the value you set as `VERSION` above:
   - MAJOR — any breaking change to the public API, including a silent one
     as described above.
   - MINOR — backwards-compatible feature addition.
   - PATCH — backwards-compatible bug fix.
4. Update `s.version` in [`Authgear.podspec`](./Authgear.podspec) to match
   `VERSION`.
5. Commit, push the release branch, and open a PR against `main`:
   ```
   git add CHANGELOG.md Authgear.podspec
   git commit -m "Release $VERSION"
   git push -u origin release/$VERSION
   gh pr create --base main --title "Release $VERSION" --fill
   ```
6. Once the PR is approved and merged, tag the resulting commit on `main`
   with an annotated tag, and push the tag:
   ```
   git checkout main
   git pull origin main
   git tag -a "$VERSION" -m "Release $VERSION"
   git push origin "$VERSION"
   ```
   SPM and CocoaPods consumers resolve this tag directly (`Authgear.podspec`'s
   `s.source` uses `s.version` as the git tag), so pushing it is what makes
   the release available — pushing a tag does not trigger CI, which only
   runs on branch pushes and pull requests.

## How to update Gems when some Gems are vulnerable

```
# Run bash shell, if you are not using it already
bash 

# Clean PATH
export PATH=""

# Initialize PATH
. /etc/profile

# Bring in homebrew
eval "$(/opt/homebrew/bin/brew shellenv)"

# Assume you have install libyaml with homebrew, as ruby depends on it.

# Bring in asdf
. "$HOME"/.asdf/asdf.sh

# Update ruby to the latest version in ./.tool-versions

# Update Bundler to the latest version.
gem install bundler

# Use the latest version of Bundler to manage Gemfile.lock
bundle update --bundler

# Update Gems
bundle update
```
