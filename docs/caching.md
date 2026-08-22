# Caching tag lists

Displaying a record's tags normally means loading its tags. If you show tags on an index page, that
is a query per record or an `includes` on every page. Caching stores the rendered list in a column
on the taggable itself, so showing it costs nothing extra.

## Turning it on

There is no setting. Add a column named `cached_<singular context>_list` and caching switches
itself on for that context:

```ruby
class AddCachedTagListToBooks < ActiveRecord::Migration[7.2]
  def change
    add_column :books, :cached_tag_list, :string
    add_column :books, :cached_genre_list, :string
  end
end
```

`:tags` gives `cached_tag_list`, `:genres` gives `cached_genre_list` — singular, the same
inflection the generated methods use.

Check whether a context is cached:

```ruby
Book.caching_tag_list?         # generated per context
Book.caching_tag_list_on?(:genres)
```

## Using it

Nothing changes in how you read or write tags. The column is filled on save:

```ruby
book = Book.create!(title: "Dune", tag_list: "sci-fi, classic")
book.cached_tag_list  # => "sci-fi, classic"
```

Reading `tag_list` on a record loaded from the database parses the cached column instead of
querying the tags table:

```ruby
book = Book.first
book.tag_list  # no query against tags or taggings
```

Show the cached string directly when you only need to display it:

```erb
<%= book.cached_tag_list %>
```

## What it costs

The cache is a denormalisation, with the usual consequences.

- **It is written on save of the taggable, and only then.** Renaming or destroying a
  `MakeTaggable::Tag` row directly does not touch any cached column. If you let tags be edited,
  re-save the affected records, or clear the column and let it rebuild.
- **It stores the rendered string**, joined with the delimiter in force at save time. Changing
  `MakeTaggable.delimiter` afterwards leaves old rows joined the old way.
- **A `string` column has a length limit.** A record with many tags can exceed it and have its
  cached list truncated by the database. Use `text` if lists may be long.
- **It does not include owned tags**, because it is built from the same list `tag_list` returns.
  See [ownership.md](ownership.md).

Caching is worth it for read-heavy displays of tags that rarely change. It is not a substitute for
querying — `tagged_with` always goes to the taggings table, cached column or not.

## Rebuilding

Saving a record is **not** enough to rebuild its cached list. The column is only rewritten when the
tag list has been loaded or assigned during that request, and reading the list on a cached record
parses the column itself — so a stale value refreshes to the same stale value:

```ruby
book = Book.find(id)   # cached_tag_list is "one, two", but the tag is now named "uno"
book.save!
book.reload.cached_tag_list # => "one, two"   <- unchanged
```

Clear the column first, so reading the list falls through to the tags table:

```ruby
Book.find_each do |book|
  book.update_column(:cached_tag_list, nil)
  book.tag_list  # now read from tags, not from the column
  book.save!
end
```

That is the reliable way to repair cached lists after renaming or merging tags out of band.
