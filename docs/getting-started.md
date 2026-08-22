# Getting started

## Requirements

MakeTaggable needs Ruby 3.2 or newer and Active Record 7.2 or newer. It is tested against Rails
7.2, 8.0 and 8.1 on SQLite, MySQL and PostgreSQL.

## Install

Add the gem:

```shell
bundle add make_taggable
```

Copy the migrations into your application and run them:

```shell
rails make_taggable_engine:install:migrations
rails db:migrate
```

That creates two tables: `tags`, holding each distinct tag name, and `taggings`, joining a tag to
the record it was applied to. Both table names are configurable — see
[configuration.md](configuration.md).

## Make a model taggable

```ruby
class Book < ApplicationRecord
  make_taggable
end
```

Called with no arguments, `make_taggable` tags on the `:tags` context, which is the default the
rest of the library assumes. Name your own contexts instead, or as well:

```ruby
class Book < ApplicationRecord
  make_taggable :genres, :moods
end
```

Each context generates its own set of methods. `:genres` gives you `genre_list`, `genres`,
`genre_counts`, `top_genres` and more — see [contexts.md](contexts.md) for the full list.

## Read and write tags

A tag list behaves like an array of strings:

```ruby
book = Book.new(title: "Dune")

book.tag_list = "sci-fi, classic"
book.save

book.tag_list           # => ["sci-fi", "classic"]
book.tags               # => [#<MakeTaggable::Tag name: "sci-fi">, #<MakeTaggable::Tag name: "classic">]
```

Add and remove individual tags. Nothing is written until you save:

```ruby
book.tag_list.add("desert")
book.tag_list.remove("classic")
book.save
```

To pass a delimited string rather than separate arguments, ask for it to be parsed:

```ruby
book.tag_list.add("desert, epic", parse: true)
```

Assigning replaces the whole list, so `tag_list =` removes anything not in the new value.

## Permit the parameter

`tag_list` is an ordinary attribute as far as your controller is concerned:

```ruby
class BooksController < ApplicationController
  private

  def book_params
    params.expect(book: [:title, :tag_list])       # Rails 8
    # params.require(:book).permit(:title, :tag_list)   # Rails 7.2
  end
end
```

`params.expect` arrived in Rails 8. On Rails 7.2 use `require` and `permit`, as commented above.

To accept an array of tags from a multi-select, permit it as one:

```ruby
params.expect(book: [:title, {tag_list: []}])      # Rails 8
params.require(:book).permit(:title, tag_list: []) # Rails 7.2
```

## Find tagged records

```ruby
Book.tagged_with("sci-fi")                          # carries this tag
Book.tagged_with(["sci-fi", "classic"])             # carries both
Book.tagged_with(["sci-fi", "classic"], any: true)  # carries either
```

`tagged_with` returns a relation, so it chains with your own scopes and with pagination.
[querying.md](querying.md) covers every option.

## Where to go next

- [contexts.md](contexts.md) — multiple contexts, ordered tags, contexts created at runtime
- [querying.md](querying.md) — every `tagged_with` option, and the counting API
- [ownership.md](ownership.md) — tags belonging to a user, and why `tag_list` can look empty
- [configuration.md](configuration.md) — every setting
- [database.md](database.md) — schema, indexes, and per-adapter notes
