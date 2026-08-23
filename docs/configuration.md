# Configuration

Settings live on `MakeTaggable`. Set them in an initializer:

```ruby
# config/initializers/make_taggable.rb
MakeTaggable.setup do |config|
  config.force_lowercase = true
  config.remove_unused_tags = true
end
```

Or assign them directly — `MakeTaggable` forwards to the same configuration object:

```ruby
MakeTaggable.force_lowercase = true
```

## Settings

| Setting | Default | Effect |
|---|---|---|
| `force_lowercase` | `false` | Downcase tag names before saving |
| `force_parameterize` | `false` | Parameterize tag names before saving |
| `strict_case_match` | `false` | Match tags case sensitively |
| `remove_unused_tags` | `false` | Destroy a tag row when its last tagging goes |
| `tags_counter` | `true` | Maintain the `taggings_count` counter cache |
| `default_parser` | `MakeTaggable::DefaultParser` | Class used to parse tag input |
| `delimiter` | `","` | Delimiter, or delimiters, separating tags |
| `tags_table` | `:tags` | Table backing `MakeTaggable::Tag` |
| `taggings_table` | `:taggings` | Table backing `MakeTaggable::Tagging` |
| `force_binary_collation` | `false` | MySQL only: exact matching including accents |

### `force_lowercase`

Tags are downcased as they are cleaned, so `"Ruby"` is stored as `"ruby"`.

### `force_parameterize`

Tags are parameterized, so `"Ruby on Rails"` is stored as `"ruby-on-rails"`. Applied after
`force_lowercase` if both are on.

`String#parameterize` strips anything outside a conservative ASCII set, so a name with no ASCII in
it -- `"日本語"` -- has no slug to reduce to. Such a name is kept as it is rather than parameterized
into nothing and dropped.

### `strict_case_match`

Off, tag lookups are case insensitive and `"Ruby"` finds `"ruby"`; a list containing both keeps one.
On, they are two distinct tags and lookups match exactly.

Note the interaction with the database: the shipped migrations put a **case-sensitive** unique index
on `tags.name`, so `"Ruby"` and `"ruby"` can both exist as rows even with `strict_case_match` off.
The library avoids creating both, but data loaded another way can still contain them.

### `remove_unused_tags`

When the last tagging referencing a tag is destroyed, the tag row is destroyed too.

This works whether or not `tags_counter` is on. With the counter cache the tag row already carries
the count and is only re-read; without it the tag's remaining taggings are queried directly, which
costs one extra query per destroyed tagging.

### `tags_counter`

Keeps `tags.taggings_count` up to date. Turning it off avoids a write to the tags row on every
tagging, at the cost of `Tag.most_used` and `Tag.least_used`, both of which read that counter.

`remove_unused_tags` is unaffected -- it falls back to querying the tag's taggings.

Changing this on an existing application leaves the existing counts frozen at their current values
rather than resetting them.

### `default_parser`

See [parsers.md](parsers.md).

### `delimiter`

Deprecated in favour of a parser, and warns when Active Record has a logger. Delimiters are literal
strings — metacharacters are escaped for you. See [parsers.md](parsers.md).

### `tags_table` and `taggings_table`

Rename the tables, for instance to keep them out of the way of another tagging library:

```ruby
MakeTaggable.tags_table = "mt_tags"
MakeTaggable.taggings_table = "mt_taggings"
```

These are read when `MakeTaggable::Tag` and `MakeTaggable::Tagging` are first loaded and when the
migrations run, so set them in an initializer, before anything touches the models. Changing them on
an application that already has data means renaming the tables yourself.

### `force_binary_collation`

MySQL only. Switches the `tags.name` column to `utf8mb4_bin`, so names compare exactly including
accented and other multi-byte characters, and forces `strict_case_match` on.

Note that the shipped migrations already apply `utf8mb4_bin` to the column on MySQL. What this
setting adds is `strict_case_match`, which is what actually makes the library's lookups case
sensitive — see [database.md](database.md).

Because the migrations have usually applied the collation already, assigning this in an initializer
is normally a no-op: the current collation is read first and the `ALTER TABLE` is skipped when it
already matches. That matters because an initializer runs once per process — every web worker,
background worker, console and rake task — and each `ALTER TABLE` takes a metadata lock on the tags
table.

```ruby
MakeTaggable.force_binary_collation = true
```

Or as a one-off migration:

```shell
rails make_taggable_engine:tag_names:collate_bin
```

Setting `strict_case_match = false` afterwards has no effect while binary collation is on. See
[database.md](database.md).
