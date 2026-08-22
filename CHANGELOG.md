# Changelog

All notable changes to this project are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed

- Documentation examples used `params.expect` and `ActiveRecord::Migration[8.0]`, neither of which
  exists on Active Record 7.2 -- the version the gem promises to support. Both are corrected, and
  `spec/docs_spec.rb` now fails the build if either creeps back.

### Internal

- Added documentation checks to the suite: every Ruby block in the README and `docs/` must parse,
  example migrations must declare a version the floor accepts, version-sensitive calls must be
  shown alongside an alternative, and relative links must resolve. They run on every Rails version
  in the matrix.

## [1.1.0] - 2026-08-22

### Added

- A migration adding `taggings_unowned_idx`, a partial unique index that stops duplicate unowned
  taggings at the database level. `taggings_idx` never could: it spans the nullable tagger columns,
  and SQL compares nulls as distinct, so only the model validation stood in the way and a validation
  cannot win a race. MySQL has no partial indexes, so the migration is a no-op there.

  Install it with `rails make_taggable_engine:install:migrations`. If it fails, the table already
  holds duplicates -- see [docs/database.md](docs/database.md).

### Internal

- The suite runs in random order. Examples were leaking state into each other: tagging declarations
  on the shared models, and the library configuration -- one example leaving `remove_unused_tags`
  on could make an unrelated example fail a foreign key check. Both are now snapshotted and restored
  around every example.

## [1.0.0] - 2026-08-22

### Breaking

- **Removed the `acts_as_*` method names.** Use `make_taggable`, `make_ordered_taggable` and
  `make_tagger` in place of `acts_as_taggable`, `acts_as_taggable_on`, `acts_as_ordered_taggable`,
  `acts_as_ordered_taggable_on` and `acts_as_tagger`.
- **Delimiters are literal strings.** They were previously interpolated into a pattern unescaped,
  so a delimiter containing a regular expression metacharacter had to be escaped by hand. Pass
  `"|"` where you previously passed `'\|'`.
- **`make_taggable` with no arguments now tags on `:tags`.** It previously added no contexts at
  all, despite the README documenting otherwise.
- **Raised the minimum versions** to Ruby 3.2 and Active Record 7.2, and removed the Active Record
  upper bound.

See [UPGRADING.md](UPGRADING.md).

### Fixed

- Tags containing non-ASCII characters no longer raise
  `Encoding::UndefinedConversionError`. `Tag.named_any` was forcing sanitised SQL to `BINARY`.
- A delimiter containing a regular expression metacharacter no longer corrupts parsing. A `"."`
  delimiter previously discarded every tag.
- `MakeTaggable::Dirty` and `MakeTaggable::Compatibility` no longer raise `LoadError`. Both were
  declared as autoloads pointing at files that do not exist.
- `MakeTaggable.delimiter=` no longer raises `NoMethodError` when Active Record has no logger,
  which is the case in a plain Active Record process or an initializer that runs early.
- Class names are parameterised through `sanitize_sql` rather than interpolated into SQL.
- `Tag.find_or_create_with_like_by_name` matches the whole name rather than a substring of it.
  Asking for `"ruby"` while a tag named `"ruby on rails"` existed returned that tag instead of
  creating the one requested. It is also no longer at the mercy of the column's collation, which
  the MySQL migration sets to `utf8mb4_bin` -- on MySQL the method created a duplicate row for a
  name differing only in case, despite `strict_case_match` being off.
- `Tag.find_or_create_all_with_like_by_name` no longer creates two rows for a list holding two
  spellings of one name, such as `["Ruby", "ruby"]`. Tags created during the call were invisible to
  the names that followed. Tagging through a tag list was never affected, since the list dedupes
  before the lookup.

### Changed

- Replaced `String#mb_chars` and `ActiveSupport::Multibyte::Chars`, both removed in Rails 8.2, with
  plain String methods.
- Removed the Active Record 5 compatibility branches and the Rails 5 `count` workaround's dead
  argument.
- Added `frozen_string_literal` to every file in `lib`.
- The deprecation warning on `MakeTaggable.delimiter=` no longer refers to a "v4.0" that does not
  exist in this gem's history.

### Documentation

- Public API documentation coverage raised from 38.65% to 100%, with no YARD warnings.
- Rewrote the README against the actual API, and added a `docs/` directory covering contexts,
  querying, ownership, parsers, caching, tag clouds, configuration, the database schema, and
  migrating from acts-as-taggable-on.

### Internal

- Replaced the test harness. The suite runs against bare Active Record instead of a generated dummy
  application, dropping the `rails-dummy` dependency and the `create_test_app` step, and builds its
  schema from the gem's own migrations.
- Replaced `spec/make_taggable/tag_spec.rb`. The file of that name contained no tests: it was a
  stale copy of `lib/make_taggable/tag.rb` that RSpec loaded, silently redefining
  `MakeTaggable::Tag` and reverting it part way through the suite. `MakeTaggable::Tag` now has 45
  unit specs, covering validations, every lookup and creation method, comparison, the scopes, and
  the taggings association.
- CI covers Rails 7.2, 8.0, 8.1 and main on Ruby 3.2 through 4.0.

## [0.7.5] - 2021-03-17

Earlier releases predate this changelog. See the
[commit history](https://github.com/MatthewKennedy/make_taggable/commits/master) for 0.7.x and
below.
