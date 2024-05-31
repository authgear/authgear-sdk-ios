## How to update Gems when some Gems are vulnerable

- Update ruby to the latest version in [.tool-versions](./tool-versions)
- Update Bundler to the latest version with `gem install bundler`
- Use the latest version of Bundler to manage Gemfile.lock `bundle update --bundler`.
- Update Gems with `bundle update`.
