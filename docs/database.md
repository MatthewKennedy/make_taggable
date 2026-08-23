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

Migrations 2 and 5 between them put twelve indexes on `taggings`. Migration 7 drops five of them,
leaving seven:

| Index | Columns | Why it is there |
|---|---|---|
| `taggings_idx` | `tag_id, taggable_id, taggable_type, context, tagger_id, tagger_type` | Unique. Stops a tag being applied twice in the same context by the same tagger |
| `taggings_unowned_idx` | `tag_id, taggable_id, taggable_type, context` where `tagger_id IS NULL` | Unique, partial. See below. Not created on MySQL |
| `taggings_taggable_context_idx` | `taggable_id, taggable_type, context` | Reading one record's tags in one context |
| `taggings_idy` | `taggable_id, taggable_type, tagger_id, context` | Reading one record's owned tags |
| — | `taggable_type, taggable_id` | The polymorphic association lookup |
| — | `tagger_id, tagger_type` | `Tagging.owned_by`, and `tagged_with(owned_by:)` |
| — | `context` | Filtering taggings by context alone |

The five migration 7 removes were `tag_id`, `taggable_id`, `taggable_type` and `tagger_id` on their
own, plus a second copy of the tagger pair in the opposite column order. A B-tree index already
answers any query filtering on a leading subset of its columns, so a single-column index earns
nothing when another index starts with that same column — and every index is maintained on insert.

If you installed the migrations before version 1.2.0, running
`rails make_taggable_engine:install:migrations` again copies migration 7 across. It is reversible,
and nothing it drops is load-bearing: each one is a prefix of an index that remains.

### Concurrent tag creation

`tags.name` carries a unique index, so two requests creating the same tag at the same moment leave
one of them holding an `ActiveRecord::RecordNotUnique`.

`Tag.find_or_create_all_with_like_by_name` -- which every tag list goes through -- absorbs that. It
re-reads the tags and retries, up to three times, and raises
{MakeTaggable::DuplicateTagError} if the name is still taken after that.

Each insert takes a savepoint of its own, so the failed insert is the only thing rolled back. If you
call this inside a transaction of your own, that transaction and everything written into it survive
the retry:

```ruby
Order.transaction do
  order.update!(state: "placed")
  order.tag_list = "priority"   # a race here rolls back nothing but the tag insert
  order.save!
end
```

### Duplicate unowned taggings

`taggings_idx` is unique across
`[tag_id, taggable_id, taggable_type, context, tagger_id, tagger_type]`. Because `tagger_id` and
`tagger_type` are null on every tagging nobody owns, and SQL compares nulls as distinct, that index
does not stop two identical unowned taggings. Only the model validation does, and a validation
cannot win a race between two concurrent writes.

Migration 6 closes it with a partial unique index, `taggings_unowned_idx`, covering
`[tag_id, taggable_id, taggable_type, context]` where `tagger_id IS NULL`.

**MySQL has no partial indexes**, so it keeps the validation on its own and the migration is a no-op
there. If duplicate taggings would be a serious problem on MySQL, the usual workaround is a
generated column holding a sentinel for the null tagger, indexed uniquely alongside the rest.

If the migration fails with a uniqueness error, the table already contains duplicates. Remove them
first:

```ruby
duplicates = MakeTaggable::Tagging
  .where(tagger_id: nil)
  .group(:tag_id, :taggable_id, :taggable_type, :context)
  .having("COUNT(*) > 1")
  .pluck(Arel.sql("MIN(id), COUNT(*)"))

duplicates.each do |keep_id, _count|
  tagging = MakeTaggable::Tagging.find(keep_id)
  MakeTaggable::Tagging
    .where(tagger_id: nil, tag_id: tagging.tag_id, taggable_id: tagging.taggable_id,
      taggable_type: tagging.taggable_type, context: tagging.context)
    .where.not(id: keep_id)
    .delete_all
end
```

## PostgreSQL

- `named_like` uses `ILIKE`, so partial matching is case insensitive regardless of collation.
- Queries group by the primary key. PostgreSQL wanted every selected non-aggregated column listed
  before 9.1; since then it works the dependency out itself.

**Case-insensitive matching of non-ASCII tags depends on the locale the cluster was created with.**
Exact matching goes through `LOWER(name) = LOWER(?)`, and `LOWER()` follows `lc_ctype`. On a UTF-8
locale it folds Cyrillic, Greek and the rest as you would expect. On a cluster initialised with
`lc_ctype = C` it folds ASCII only, and `"ПРИВЕТ"` and `"привет"` become two separate tags — the same
limitation described under SQLite below, on a database that otherwise has none.

Check with:

```sql
SHOW lc_ctype;          -- C means ASCII-only folding
SELECT LOWER('Ü');      -- returns 'Ü' unchanged on such a cluster
```

`ILIKE` is unaffected, so partial matching keeps working either way. If you need exact matching to
fold non-ASCII, create the database with a UTF-8 locale, or set
`MakeTaggable.strict_case_match = true` so the behaviour is at least consistent.

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

A tag that cannot be saved fails the save of the record being tagged. `save!` raises
`ActiveRecord::RecordInvalid` carrying the **tag**, so the error says what was wrong with it and
`error.record` is the tag itself; `save` returns `false` and writes nothing.

The same applies to a `Tag` subclass with validations of its own:

```ruby
class PickyTag < MakeTaggable::Tag
  validate { errors.add(:name, "must not be rude") if name.to_s.include?("rude") }
end

article.save!
# => ActiveRecord::RecordInvalid: Validation failed: Name must not be rude
```

See [contexts.md](contexts.md) for wiring a `Tag` subclass to a context.
