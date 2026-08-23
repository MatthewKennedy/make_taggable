# MakeTaggable

[![Gem Version](https://img.shields.io/gem/v/make_taggable)](https://rubygems.org/gems/make_taggable)
[![Downloads](https://img.shields.io/gem/dt/make_taggable)](https://rubygems.org/gems/make_taggable)
[![CI](https://github.com/MatthewKennedy/make_taggable/actions/workflows/ci.yml/badge.svg)](https://github.com/MatthewKennedy/make_taggable/actions/workflows/ci.yml)
[![Standard Rb](https://github.com/MatthewKennedy/make_taggable/actions/workflows/standard-ci.yml/badge.svg)](https://github.com/MatthewKennedy/make_taggable/actions/workflows/standard-ci.yml)
[![Sponsor](https://img.shields.io/github/sponsors/MatthewKennedy?label=sponsor&logo=github)](https://github.com/sponsors/MatthewKennedy)

Tagging for Active Record models, across any number of named contexts.

One model can carry several independent sets of tags — genres and moods, skills and interests —
each with its own list, counts and queries. Tags can belong to the user who applied them, keep the
order they were added in, and be cached on the record for display.

## Requirements

| Component | Supported |
|---|---|
| Ruby | 3.2 or newer |
| Active Record | 7.2 or newer |
| Databases | PostgreSQL, MySQL, SQLite |

Tested against Rails 7.2, 8.0 and 8.1 on Ruby 3.2 through 4.0.

## Install

```shell
bundle add make_taggable
```

```shell
rails make_taggable_engine:install:migrations
rails db:migrate
```

## Quick start

```ruby
class Book < ApplicationRecord
  make_taggable            # the :tags context, for free-form tags
  make_taggable :genres    # a context of your own, for a curated set
end
```

Each context is a separate set of tags, with its own list:

```ruby
book = Book.create!(title: "Dune", genre_list: "sci-fi, classic")

book.genre_list                  # => ["sci-fi", "classic"]
```

Add and remove individual tags. Nothing is written until you save:

```ruby
book.genre_list.add("space opera")
book.genre_list.remove("classic")
book.save

book.genre_list                  # => ["sci-fi", "space opera"]
book.genres                      # => [#<MakeTaggable::Tag name: "sci-fi">, #<MakeTaggable::Tag name: "space opera">]
```

Assigning replaces the whole list, and the two contexts never touch each other:

```ruby
book.tag_list = "desert, chosen-one, re-read"
book.save

book.tag_list                    # => ["desert", "chosen-one", "re-read"]
book.genre_list                  # => ["sci-fi", "space opera"]
```

Find them again:

```ruby
Book.tagged_with("sci-fi")                             # carries this tag
Book.tagged_with(["sci-fi", "space opera"])            # carries both
Book.tagged_with(["sci-fi", "fantasy"], any: true)     # carries either
Book.tagged_with(["fantasy"], exclude: true)           # carries neither
```

Scope a query to one context, and tags in the others stop counting:

```ruby
Book.tagged_with("sci-fi", on: :genres)                # => [#<Book title: "Dune">]
Book.tagged_with("sci-fi", on: :tags)                  # => []
```

Counts, for tag clouds and "most used" lists:

```ruby
Book.tag_counts_on(:genres)                            # tags carrying a `count`
Book.top_genres(10)
```

Tags are ordinary attributes as far as your controller is concerned:

```ruby
params.expect(book: [:title, :tag_list])            # Rails 8
params.require(:book).permit(:title, :tag_list)     # Rails 7.2
```

## Documentation

| Guide | Covers |
|---|---|
| [Getting started](docs/getting-started.md) | Install, first tagged model, reading and writing |
| [Tag contexts](docs/contexts.md) | Multiple contexts, ordered tags, contexts created at runtime |
| [Querying](docs/querying.md) | Every `tagged_with` option, counting, related records |
| [Ownership](docs/ownership.md) | Taggers, owned tags, and why `tag_list` can look empty |
| [Parsers and delimiters](docs/parsers.md) | Custom parsers, delimiters, escaping |
| [Caching](docs/caching.md) | `cached_*_list` columns, and what they cost |
| [Tag clouds](docs/tag-clouds.md) | Counts and the `tag_cloud` helper |
| [Configuration](docs/configuration.md) | Every setting |
| [Database](docs/database.md) | Schema, indexes, per-adapter notes |
| [Migrating from acts-as-taggable-on](docs/migrating-from-aato.md) | Method and constant mapping |

API documentation is generated with YARD:

```shell
bundle exec yard doc
```

## Upgrading

See [UPGRADING.md](UPGRADING.md). Version 1.0 removes the `acts_as_*` method names and changes how
delimiters are escaped.

Install new migrations when upgrading:

```shell
rails make_taggable_engine:install:migrations
rails db:migrate
```

## Development

The test suite runs against bare Active Record — there is no dummy application to generate.

```shell
bundle install
bundle exec rake
```

That uses in-memory SQLite. To run against another adapter, point it at a database:

```shell
DATABASE_ADAPTER=postgresql DATABASE_URL=postgres://localhost/make_taggable_test bundle exec rake
DATABASE_ADAPTER=mysql2 DATABASE_URL=mysql2://root@127.0.0.1/make_taggable_test bundle exec rake
```

Across every supported Rails version:

```shell
bundle exec appraisal install
bundle exec appraisal rake
```

Format with Standard before opening a pull request:

```shell
bundle exec standardrb --fix
```

Public API needs YARD documentation. `bundle exec yard stats --list-undoc` should report 100%.

See [CONTRIBUTING.md](CONTRIBUTING.md) for more.

## Sponsoring

MakeTaggable is free to use under the MIT licence, and maintained in spare time. If it saves you
some, you can [sponsor its development](https://github.com/sponsors/MatthewKennedy).

Sponsorship buys no support commitment and no influence over what gets built — bug reports and pull
requests are as welcome from everyone as they always were.

## Credits

MakeTaggable is a fork of [acts-as-taggable-on](https://github.com/mbleigh/acts-as-taggable-on) by
Michael Bleigh and Joost Baaij, with thanks to
[its contributors](https://github.com/mbleigh/acts-as-taggable-on/contributors).

## License

Available as open source under the terms of the [MIT License](LICENSE.md).
