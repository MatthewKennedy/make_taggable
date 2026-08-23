# Contributing

## Bug reports

Check for an [existing issue](https://github.com/MatthewKennedy/make_taggable/issues) first, then
[open a new one](https://github.com/MatthewKennedy/make_taggable/issues/new).

Please include the version of the gem, your Ruby and Rails versions, your database adapter, and the
smallest model and code that reproduce the problem.

## Making a change

1. [Fork and clone the repo](https://help.github.com/articles/fork-a-repo).
2. `bundle install`.
3. Write a failing test first, then make it pass.
4. Run the suite: `bundle exec rake`.
5. Format: `bundle exec standardrb --fix`.
6. Document any public API you added: `bundle exec yard stats --list-undoc` should report 100%.
7. Add an entry to [CHANGELOG.md](CHANGELOG.md) under "unreleased".
8. If it changes something an application would have to react to, add it to
   [UPGRADING.md](UPGRADING.md) — that file is the gem's post-install message.
9. Open a pull request explaining what changed and why.

Keep commits small and well described, and link any relevant issues. Don't bump the version — that
happens at release.

## Running the tests

The suite runs against bare Active Record, using in-memory SQLite by default. There is no dummy
application to generate.

```shell
bundle exec rake
```

Against another adapter:

```shell
DATABASE_ADAPTER=postgresql DATABASE_URL=postgres://localhost/make_taggable_test bundle exec rake
DATABASE_ADAPTER=mysql2 DATABASE_URL=mysql2://root@127.0.0.1/make_taggable_test bundle exec rake
```

Worth doing before opening a pull request if you touched anything that generates SQL. Several bugs
in this gem only appeared on one adapter — SQLite in particular is forgiving enough to hide them,
and one of them passed on SQLite only because it treats an unresolvable double-quoted identifier as
a string literal.

The concurrency example does not run on SQLite. It needs an adapter that supports real concurrent
writes, so it is skipped there and runs on MySQL and PostgreSQL.

## Coverage

```shell
COVERAGE=1 bundle exec rspec
```

The run fails if coverage drops below the floor set in `spec/spec_helper.rb`, and CI runs it on
every pull request. Raise the floor when coverage improves; never lower it to make a run pass.

Coverage is a way of finding untested paths, not a target. The last time it was measured it pointed
straight at an untested option combination that turned out to be broken.

Across every supported Rails version:

```shell
bundle exec appraisal install
bundle exec appraisal rake
```

### A note on test ordering

The suite runs in random order, so an example that depends on a sibling having run first will fail
sooner or later. Reproduce a failure with the seed it reports:

```shell
bundle exec rspec --order random:12345
```

Examples are free to change global state — the tagging declarations on the shared models, and the
`MakeTaggable` configuration — because `spec_helper.rb` snapshots both and restores them after every
example. Anything else you make global is yours to clean up.

## Documentation

Prose documentation lives in [docs/](docs). API documentation is YARD comments in `lib`, following
the style already there: a `##` opening line, a description, a blank line, then tags with real Ruby
types.

`spec/docs_spec.rb` holds the prose to the versions the gemspec promises. It checks that every Ruby
block parses, that no example declares a migration version newer than the supported floor, that
calls the floor does not have are shown alongside an alternative, and that every relative link
resolves. It runs with the rest of the suite, so it runs on every Rails version in the matrix --
including the oldest, which is where documentation written on the newest tends to break.

Build it locally with `bundle exec yard doc`.

## Releasing

Maintainers only. Bump `lib/make_taggable/version.rb`, move the "unreleased" changelog heading to
the new version, then tag:

```shell
git tag v1.0.0
git push origin v1.0.0
```

The release workflow runs the suite, checks formatting and documentation coverage, and publishes to
RubyGems via trusted publishing.
