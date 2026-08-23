# Querying

## `tagged_with`

`tagged_with` returns a relation, so it chains with your own scopes, with `order`, and with
pagination.

```ruby
Book.tagged_with("sci-fi").order(published_at: :desc).limit(20)
```

By default every tag given must be present:

```ruby
Book.tagged_with(["sci-fi", "classic"])                # carries sci-fi AND classic
Book.tagged_with(["sci-fi", "classic"], any: true)     # carries sci-fi OR classic
Book.tagged_with(["sci-fi", "classic"], exclude: true) # carries NEITHER
```

Passing nothing matches nothing. `Book.tagged_with([])` and `Book.tagged_with("")` both return an
empty relation rather than every record — worth knowing when the tags come from user input.

### Options

| Option | Effect |
|---|---|
| `:any` | Match records carrying at least one of the tags |
| `:exclude` | Match records carrying none of the tags |
| `:match_all` | Match records carrying only these tags and no others |
| `:wild` | Match tags *containing* the given text, i.e. `%sci%` |
| `:on` | Restrict to one context. Honoured by every option, `:exclude` included |
| `:owned_by` | Restrict to tags applied by one tagger |
| `:order_by_matching_tag_count` | With `:any`, order by how many tags matched, most first |
| `:start_at` | Only tags applied after this time. Honoured by every option, `:exclude` included |
| `:end_at` | Only tags applied before this time. Honoured by every option, `:exclude` included |

An empty tag list means "nothing matches" for the matching options and "nothing is ruled out" for
`:exclude`, so the two always partition the scope between them:

```ruby
Book.tagged_with([])                  # => none
Book.tagged_with([], exclude: true)   # => every book
```

`:wild` combines with `:any` or `:exclude`:

```ruby
Book.tagged_with(["sci", "clas"], any: true, wild: true)
```

Contexts are matched one call at a time, so chain to combine them:

```ruby
Book
  .tagged_with(["sci-fi", "fantasy"], on: :genres, any: true)
  .tagged_with(["desert", "space"], on: :tags, any: true)
```

### Case sensitivity

Tag matching is case insensitive by default: `tagged_with("Ruby")` finds records tagged `"ruby"`.
Set `MakeTaggable.strict_case_match = true` to match exactly. See
[configuration.md](configuration.md), and the SQLite note in [database.md](database.md) — SQLite
cannot change the case of non-ASCII characters without an extension.

## Counting tags

`tag_counts_on` returns tags with a `count` attribute, which is what tag clouds are built from.

```ruby
Book.tag_counts_on(:genres)
book.tag_counts_on(:genres)      # just this book's genres
Book.genre_counts                # the same, generated per context
Book.top_genres(10)              # the ten most used, most first
```

`count` is an attribute on the returned tags, not a method call on the relation:

```ruby
Book.tag_counts_on(:genres).each do |tag|
  puts "#{tag.name}: #{tag.count}"
end
```

### `all_tags` and `all_tag_counts`

The generated methods above are wrappers around these two, which take the full option set:

```ruby
Book.all_tag_counts(
  on: :genres,
  at_least: 5,
  at_most: 100,
  order: "count desc",
  limit: 20,
  start_at: 1.month.ago
)
```

| Option | `all_tags` | `all_tag_counts` | Effect |
|---|:--:|:--:|---|
| `:on` | ✓ | ✓ | Restrict to one context |
| `:start_at` | ✓ | ✓ | Only tags applied after this time |
| `:end_at` | ✓ | ✓ | Only tags applied before this time |
| `:conditions` | ✓ | ✓ | SQL conditions added to the tag query |
| `:order` | ✓ | ✓ | SQL to order by |
| `:limit` | ✓ | ✓ | Most tags to return |
| `:at_least` | | ✓ | Skip tags used fewer times than this |
| `:at_most` | | ✓ | Skip tags used more times than this |

Use `all_tags` when you only need the names: it skips the join onto the taggable table, so it is
noticeably cheaper on a large table.

## Related records

These examples switch to a `User` model tagged on `:skills` — sharing tags is easiest to picture
with people.

Records sharing tags with this one, ordered by how many tags matched:

```ruby
tom.skill_list      # => ["hacking", "jogging", "diving"]
bobby.skill_list    # => ["jogging", "diving"]
frankie.skill_list  # => ["hacking"]

tom.find_related_skills     # => [bobby, frankie]
bobby.find_related_skills   # => [tom]
```

Ignore some tags, or search a different model:

```ruby
tom.find_related_skills(ignore: ["jogging"])
tom.find_related_skills_for(Company)
```

To match one context's tags against a different context's, use `find_matching_contexts`:

```ruby
# users whose :interests match this user's :skills
user.find_matching_contexts(:skills, :interests)
user.find_matching_contexts_for(Company, :skills, :markets)
```

Both return records carrying a `count` attribute holding the number of matching tags.

## Tags directly

`MakeTaggable::Tag` is an ordinary model, so query it when you want the vocabulary rather than the
records:

```ruby
MakeTaggable::Tag.most_used            # default limit 20
MakeTaggable::Tag.least_used(10)
MakeTaggable::Tag.named("ruby")        # exact, honouring case sensitivity
MakeTaggable::Tag.named_any(%w[ruby rails])
MakeTaggable::Tag.named_like("rub")    # contains
MakeTaggable::Tag.for_context(:skills) # used in this context, on any model
```

`most_used` and `least_used` read the `taggings_count` counter cache, so they do not aggregate at
query time. If you set `MakeTaggable.tags_counter = false` that counter is not maintained and both
scopes will be wrong.

## Performance notes

- `tagged_with` with several tags and no `:any` adds one join per tag. Matching a dozen tags in a
  single call generates a dozen joins; prefer `any: true` where the semantics allow it.
- `:order_by_matching_tag_count` adds a correlated subquery to the `ORDER BY`. It is fine for a
  page of results and expensive across a whole table.
- `all_tag_counts` joins the taggables to count them. Reach for `all_tags` when the counts are not
  needed.
- Caching a rendered list in a column avoids loading tags to display them. See
  [caching.md](caching.md).
