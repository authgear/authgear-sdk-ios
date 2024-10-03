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
