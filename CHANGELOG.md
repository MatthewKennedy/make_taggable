# Changelog

All notable changes to this project are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.5.0] - 2026-08-23

### Added

- `:on` accepts several contexts as well as one, so a query can search a subset:
  `tagged_with("classic", on: [:genres, :moods], any: true)`. Passing an array previously raised
  `TypeError` from inside Arel.

### Fixed

- `force_parameterize` discarded a tag outright when the name had no ASCII in it. `parameterize`
  reduces such a name to an empty string, which was then rejected as blank, so a user tagging in
  Japanese, Greek, Hebrew, Arabic or Cyrillic saved successfully and got back fewer tags than they
  typed. The parameterized form is now kept only where there is one.

- `force_binary_collation = true` ran an `ALTER TABLE` every time it was assigned, with no check for
  whether the column already carried that collation. The documented home for it is an initializer,
  which runs once per process, so a deployment issued a schema change against the `tags` table from
  every web worker, background worker, console and rake task -- each one taking a metadata lock that
  other queries queue behind. The current collation is now read first and the statement skipped when
  it matches. The blanket `rescue`/`puts` around it is replaced by an explicit `table_exists?` check.

- On PostgreSQL, tag names were matched as `LOWER(name) ILIKE ...`. `ILIKE` already folds case, so
  the `LOWER()` changed nothing while making the expression non-sargable -- no index on `tags.name`
  could be used, including a trigram index built for wild searches. It is skipped on PostgreSQL and
  kept on the adapters that need it.

- Taggings are created in tag id order. Each insert bumps the tag's counter cache, so two concurrent
  saves touching the same tags took row locks in whatever order their lists happened to be in, which
  invites deadlocks. Models using `make_ordered_taggable` are unaffected -- there the creation order
  carries the meaning.

## [1.4.0] - 2026-08-23

### Fixed

- `find_related_*` raised on `.count`. The relation selects the taggable's columns plus an aliased
  count, and Active Record folded that select list into the `COUNT()` it built. It now counts the
  grouped query as a subquery, so `.count` and `.size` return the number of related records.

- `find_related_*` raised on PostgreSQL for any taggable model with a `json` column -- the query
  grouped by every column on the table, and `json` has no equality operator so it cannot appear in
  a `GROUP BY`. It now groups by the primary key on every adapter, which is what the other adapters
  already did. `jsonb` was never affected, so the column type an application picked decided whether
  the feature worked at all.

- `TagList` could not be serialised to YAML. Every list carried its parser in an instance variable,
  and that variable holds a Class, which Psych refuses to dump. Anything serialising a model's
  attributes hit it -- change-history gems, Active Job arguments, `serialize` columns. The parser is
  no longer stored; the reader falls back to the configured `MakeTaggable.default_parser`. One
  consequence: a list now follows the configured parser rather than the one in force when it was
  built.

- `TagList#remove` ignored a symbol. `remove(:foo)` silently did nothing where `remove("foo")`
  worked.

- A tag that failed validation was reported as `Tag can't be blank`, naming the wrong attribute for
  the wrong reason -- reachable with no customisation, since the shipped `Tag` validates name length
  at 255 characters. The error now carries the tag itself, so it says what was actually wrong and
  `error.record` is the tag. `save!` raises; `save` still returns `false` and writes nothing.

- Saving a taggable read every tagging on the record, on every save, before establishing whether
  any tag list had been assigned. That cost a query per save and made the gem unusable under
  `strict_loading` -- a record whose tags were never touched still raised
  `StrictLoadingViolationError`. Saves now consider only the contexts held in memory.

### Changed

- **Tag lists are no longer declared as Active Model attributes.** The declaration is what gave them
  dirty tracking, and it also made Active Record treat them as columns where they are not. The dirty
  API is unchanged -- `tag_list_changed?`, `_was`, `_change`, `will_save_change_to_*`,
  `saved_change_to_*`, and the tag lists still appear in `changes` -- but it now runs on the gem's
  own bookkeeping.

  Three visible consequences, each of them the point:

  - `as_json` no longer includes tag lists, so serialising a collection no longer queries once per
    record. Serialising three records went from 16 queries to 1. Ask for a list explicitly with
    `as_json(methods: :tag_list)`.
  - `attributes` no longer carries a `tag_list` key. It previously held `nil` while `tag_list`
    returned the tags.
  - `upsert_all` still refuses a tag list -- it writes columns, and a tag list means writing
    taggings -- but `as_json` output can now be round-tripped through it, which it could not before.

  `MakeTaggable::Taggable::TagListType` is removed. It backed the attribute and has no other caller.

### Fixed

- `tag_ids = []` silently did nothing once `as_json` had been called on the record.

- Mutating a list in place -- `record.tag_list.add("x")` -- did not mark the record as changed, so
  `tag_list_changed?` stayed false and anything conditioned on it never ran. The list still saved;
  what was wrong was everything that asks the record what changed.

## [1.3.0] - 2026-08-23

### Changed

- **`tagged_with` no longer joins the taggings table.** It tests for each tag with an `EXISTS`
  subquery instead, which is what stops a record being returned once per matching tagging. A tag
  applied in two contexts, or a `:wild` pattern matching two of a record's tags, returned that
  record twice; `.count` disagreed with the number of records, and pagination pages ran short.

  The consequence for callers is that a `taggings` column is no longer in scope on the relation, so
  `tagged_with("x").order("taggings.created_at")` or a `group` on a taggings column now needs an
  explicit `.joins(:taggings)`. See [docs/querying.md](docs/querying.md).

  Matching a dozen tags now produces a dozen correlated subqueries rather than a dozen joins.
  `:match_all` is unchanged and keeps its join.

### Fixed

- `tagged_with(..., any: true)` forced `SELECT taggable_models.*` onto the relation. That made
  `.count` emit `COUNT("table".*)`, which no adapter accepts, and left a caller's own `select`
  appended after the star rather than replacing it -- so every column came back regardless, and the
  relation could not be used inside a `merge`. The strategy filters with an `EXISTS` subquery and
  joins nothing, so Active Record's default select list was already right.

- `:order_by_matching_tag_count` raised on the default all-tags path, and the expression behind it
  was invalid SQL that would have ordered nothing even where it parsed. Both strategies now share
  the correlated count the `:any` path has always used, so the option orders correctly on either.
  It still has no effect alongside `:match_all`.

- `tagged_with(..., exclude: true)` ignored `:start_at` and `:end_at`, excluding records on the
  strength of taggings from outside the window entirely.

## [1.2.1] - 2026-08-23

### Fixed

- `tagged_with(..., exclude: true)` raised on any model whose primary key is not `id`. The exclude
  strategy built its `NOT IN` predicate against a hardcoded `id` column, where the other two
  strategies already used the model's primary key.

- `tagged_with(..., on: <context>, exclude: true)` ignored the context entirely, gathering taggings
  from every context, so a record tagged in one context was excluded from a query about another.

- `tagged_with([], exclude: true)` returned nothing rather than everything. Excluding no tags rules
  nothing out, so the whole scope now stands. This restores the property that `tagged_with(list)`
  and `tagged_with(list, exclude: true)` partition the scope between them for any list.

- A tag context whose name cannot become a Ruby method name -- one starting with a digit, say --
  raised `SyntaxError` while the model was loading, from inside Active Record's association
  builder. Since `SyntaxError` is not a `StandardError` it slipped past application rescues.
  Contexts are now checked as they are declared and rejected with an `ArgumentError` naming the
  context. Non-ASCII context names keep working.

### Internal

- The suite's schema teardown no longer depends on the order `connection.tables` returns. MySQL
  ignores `DROP TABLE ... CASCADE` for foreign keys, so it only worked because `taggings` happens
  to sort before `tags`.

## [1.2.0] - 2026-08-23

### Fixed

- `Tag.find_or_create_all_with_like_by_name` recovered from a lost race for a tag name by issuing a
  raw `ROLLBACK`. That statement is not scoped to the failed insert -- it discarded whatever
  transaction was open on the connection, which is nearly always one the caller opened, and on a
  multi-database application it targeted whichever connection `ActiveRecord::Base` held rather than
  the one the tags are on. Each insert now takes a savepoint of its own.

- `remove_unused_tags` did nothing at all when `tags_counter` was off, because the check read the
  counter cache. With the counter off it now asks the tag's taggings directly, at the cost of one
  indexed lookup per destroyed tagging. The documentation said the setting required `tags_counter`;
  it no longer does.

- `Utils.using_postgresql?` matched only the adapter named `PostgreSQL`, so a PostGIS application
  took the MySQL path -- `LIKE` in place of `ILIKE`, which quietly made tag matching
  case-sensitive, and the wrong grouping strategy in `all_tags_on` and `find_related_*`.

### Changed

- A migration dropping five indexes from `taggings` that no query planner can reach: `tag_id`,
  `taggable_id`, `taggable_type` and `tagger_id` on their own, each a leading column of an index
  that remains, plus a second copy of the tagger pair in the opposite column order. Twelve indexes
  become seven, and every one of them is maintained on insert.

  Install it with `rails make_taggable_engine:install:migrations`. It is reversible -- see
  [docs/database.md](docs/database.md).

## [1.1.1] - 2026-08-22

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
