# Database

## Schema

Two tables, installed by `rails make_taggable_engine:install:migrations`.

**`tags`** — one row per distinct tag name.

| Column | Type | Notes |
|---|---|---|
| `name` | string | Limited to 255 characters by a validation; uniquely indexed |
| `taggings_count` | integer | Counter cache, maintained unless `tags_counter` is off |
| `created_at`, `updated_at` | datetime | |

**`taggings`** — joins a tag to the record it was applied to.

| Column | Type | Notes |
|---|---|---|
| `tag_id` | reference | Foreign key to `tags` |
| `taggable_type`, `taggable_id` | polymorphic reference | The record being tagged |
| `tagger_type`, `tagger_id` | polymorphic reference | Who applied it; null when unowned |
| `context` | string(128) | The tag context, e.g. `"skills"` |
| `created_at`, `updated_at` | datetime | |

Both table names are configurable — see [configuration.md](configuration.md).

## Indexes

The shipped migrations index `taggings` heavily: the polymorphic references index themselves, and
migration 5 adds standalone indexes on `taggable_id`, `tagger_id`, `taggable_type` and `context`,
plus four composites.

That suits read-heavy tagging. If your application writes taggings in bulk, the write cost is worth
looking at — every index is maintained on insert, and several of the standalone ones are prefixes of
composites that already exist. Drop what your queries do not use.

### The unique index does not stop duplicate unowned taggings

`taggings_idx` is unique across
`[tag_id, taggable_id, taggable_type, context, tagger_id, tagger_type]`. Because `tagger_id` and
`tagger_type` are null for unowned taggings, and SQL treats nulls as distinct, **the database will
accept two identical unowned taggings**. Only the Active Record uniqueness validation prevents them,
and a validation cannot prevent a race between two concurrent writes.

If duplicate taggings would be a problem for you, add a partial unique index. On PostgreSQL:

```ruby
add_index :taggings,
  [:tag_id, :taggable_id, :taggable_type, :context],
  unique: true,
  where: "tagger_id IS NULL",
  name: "taggings_unowned_idx"
```

## PostgreSQL

- `named_like` uses `ILIKE`, so partial matching is case insensitive regardless of collation.
- Tag counts group by every tag column, as PostgreSQL requires.
- Nothing extra is needed for non-ASCII tags.

## MySQL

**The shipped migrations collate tag names as `utf8mb4_bin`.** Migration 3 applies it
unconditionally on MySQL, so the `tags.name` column is case- and accent-sensitive at the database
level whatever `force_binary_collation` is set to.

That matters if you query the column yourself: `WHERE name LIKE '%ruby%'` will not match `"Ruby"` on
MySQL, though it does on SQLite and PostgreSQL. The library's own lookups are unaffected, because
`Tag.named` and `Tag.named_any` compare with `LOWER()` on both sides rather than relying on the
collation.

To go back to a case-insensitive column, run `rails make_taggable_engine:tag_names:collate_ci`.

Other notes:

- For exact matching including accented characters *and* case-sensitive library lookups, turn on
  binary collation through the configuration, which also flips `strict_case_match`:

  ```ruby
  MakeTaggable.force_binary_collation = true
  ```

  or run `rails make_taggable_engine:tag_names:collate_bin`. To go back,
  `rails make_taggable_engine:tag_names:collate_ci`.

  Binary collation forces `strict_case_match` on, and `strict_case_match = false` has no effect
  while it is on.

- Tag count queries fetch matching ids first rather than using a subquery, which MySQL optimises
  poorly.

## SQLite

Fine for development and for the test suite, with one real limitation:

**SQLite cannot change the case of non-ASCII characters.** Its built-in `LOWER()` and `UPPER()`
handle ASCII only, so case-insensitive matching of, say, Cyrillic or Greek tags does not work. `"ПРИВЕТ"`
and `"привет"` are two different tags as far as SQLite is concerned.

If that matters, load the [ICU extension](https://www.sqlite.org/src/artifact?ci=trunk&filename=ext/icu/README.txt),
or set `MakeTaggable.strict_case_match = true` so the behaviour is at least consistent.

## Tag length

`name` is validated at 255 characters, and the column is a `string`. Tags longer than that fail
validation rather than being truncated.
