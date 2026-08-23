# Tag contexts

A context is a named group of tags on a model. One model can tag in as many contexts as you like,
and the tags in each are kept apart: adding `"ruby"` to `skill_list` says nothing about
`interest_list`.

```ruby
class User < ApplicationRecord
  make_taggable                        # the :tags context
  make_taggable :skills, :interests
end
```

## What each context generates

Given `make_taggable :skills`, these appear on the model. Singular and plural forms are worked out
with Active Support's inflector, so `:skills` gives `skill_list` and `skills`.

| Method | Kind | What it gives you |
|---|---|---|
| `skill_list` | instance | The tag names, as a `MakeTaggable::TagList` |
| `skill_list=` | instance | Replaces the whole list |
| `all_skills_list` | instance | The names including tags applied by an owner |
| `skills` | instance | The `MakeTaggable::Tag` records, through the association |
| `skill_taggings` | instance | The `MakeTaggable::Tagging` join records |
| `skill_counts` | class and instance | Tags used, each carrying a `count` |
| `top_skills(limit = 10)` | class and instance | The most used tags, most first |
| `skills_from(owner)` | instance | Only the tags that owner applied |
| `find_related_skills` | instance | Other records sharing these tags |
| `find_related_skills_for(klass)` | instance | The same, against another model |
| `caching_skill_list?` | class | Whether this context is cached in a column |

`skill_list` takes part in dirty tracking:

```ruby
user.skill_list = "diving"
user.skill_list_changed?             # => true
user.skill_list_was                  # => ["jogging"]
user.skill_list_change               # => [["jogging"], ["diving"]]
user.will_save_change_to_skill_list?  # => true
user.changes                          # => {"skill_list" => [["jogging"], ["diving"]]}
user.save
user.saved_change_to_skill_list?      # => true
```

Order counts only where the model asked for it with `make_ordered_taggable`. Reordering the same
tags is not a change otherwise.

A tag list is **not** an Active Record attribute, though, and the difference shows in three places:

```ruby
user.attributes["skill_list"]   # => nil, and the key is absent -- use user.skill_list
user.as_json                    # no "skill_list" key; ask for it with as_json(methods: :skill_list)
User.upsert_all([{skill_list: "diving"}])   # raises -- upsert_all writes columns, and this is not one
```

Leaving tag lists out of `as_json` is deliberate: a list is loaded from the taggings table, so
including it meant serialising a collection queried once per record.

### Naming a context

Because the context becomes part of every name in the table above, it has to be usable as a Ruby
method and instance variable name. A context starting with a digit, or containing a hyphen or a
space, is rejected when the model declares it:

```ruby
class Book < ActiveRecord::Base
  make_taggable :"1categories"
end
# => ArgumentError: :"1categories" cannot be used as a tag context: make_taggable generates
#    methods and instance variables from it, and "1categories_list" is not a valid Ruby name.
```

Validity is decided by asking Ruby, not by a pattern, so anything that makes a legal method name is
allowed — non-ASCII context names included.

## Adding contexts later

Calling `make_taggable` again adds contexts rather than replacing them, which is what lets a
subclass extend its parent:

```ruby
class Book < ApplicationRecord
  make_taggable
end

class Manual < Book
  make_taggable :audiences
end

Book.tag_types   # => [:tags]
Manual.tag_types # => [:tags, :audiences]
```

## Preserving tag order

By default tags come back in whatever order the database returns. To keep them in the order they
were added, declare the model with `make_ordered_taggable`:

```ruby
class Route < ApplicationRecord
  make_ordered_taggable            # the :tags context, ordered
  make_ordered_taggable :stops
end

route.tag_list = "east, south"
route.save
route.tag_list = "north, east, south, west"
route.save

route.reload.tag_list # => ["north", "east", "south", "west"]
```

Ordering is a property of the model, not of a single context: the last call wins for every context
on that model. It also changes what counts as a change — reordering the same tags marks the list
dirty on an ordered model, and does not on an unordered one.

## Contexts created at runtime

You do not have to declare a context up front. Anything you write through `set_tag_list_on` is
saved and read back, which is how user-defined tag groups are built:

```ruby
user = User.new(name: "Bobby")

user.set_tag_list_on(:customs, "same, as, tag, list")
user.tag_list_on(:customs)   # => ["same", "as", "tag", "list"]
user.save

user.tags_on(:customs)       # => [#<MakeTaggable::Tag name: "same">, ...]
user.tag_counts_on(:customs)

User.tagged_with("same", on: :customs) # => [user]
```

`tagging_contexts` lists everything the record tags in, declared and dynamic together:

```ruby
user.tagging_contexts # => ["tags", "skills", "interests", "customs"]
```

Dynamic contexts get none of the generated methods in the table above — there is no
`custom_list` — so reach them through `tag_list_on`, `set_tag_list_on` and `tags_on`.

## A separate vocabulary for one context

Tags are shared across contexts and models by default: one `tags` row named `"ruby"` serves
everything. To keep a context's tags separate, subclass `MakeTaggable::Tag` and override the hook
that resolves names to records:

```ruby
class Market < MakeTaggable::Tag
end

class Company < ApplicationRecord
  make_taggable :markets, :locations

  private

  def find_or_create_tags_from_list_with_context(tag_list, context)
    if context.to_sym == :markets
      Market.find_or_create_all_with_like_by_name(tag_list)
    else
      super
    end
  end
end
```

This only genuinely separates the vocabularies if the tags table has a `type` column. Without one,
Active Record has nowhere to record the subclass: rows created through `Market` are saved as plain
tags, `Market.count` returns every tag in the table, and reloading a record gives you a
`MakeTaggable::Tag` back. Add the column to get real separation:

```ruby
class AddTypeToTags < ActiveRecord::Migration[7.2]
  def change
    add_column MakeTaggable.tags_table, :type, :string
    add_index MakeTaggable.tags_table, :type
  end
end
```

Note that the shipped migrations put a unique index on `tags.name`, so two tags cannot share a name
even across subclasses. If a market and a genre both need to be called "Energy", widen that index to
cover `[:name, :type]`.
