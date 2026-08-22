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
