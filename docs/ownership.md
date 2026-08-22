# Tag ownership

A tag can be applied *by* someone. That someone is a tagger, and the tags they applied are owned by
them. It is how you build "your tags" alongside everyone else's on the same record.

## Declaring a tagger

```ruby
class User < ApplicationRecord
  make_tagger
end

class Photo < ApplicationRecord
  make_taggable :locations
end
```

`make_tagger` adds two associations to the model: `owned_taggings` and `owned_tags`.

## Applying owned tags

```ruby
user.tag(photo, with: "paris, normandy", on: :locations)
```

`with` and `on` are both required — `tag` raises without them. The taggable is saved for you unless
you pass `skip_save: true`:

```ruby
user.tag(photo, with: "paris", on: :locations, skip_save: true)
photo.save # when you're ready
```

By default you may tag in a context the model does not declare. Pass `force: false` to require a
declared context:

```ruby
user.tag(photo, with: "paris", on: :undeclared, force: false)
# => RuntimeError: No context :undeclared defined in Photo
```

## The one thing that surprises everyone

**`tag_list` never returns owned tags.** It returns only tags with no owner.

```ruby
photo.tag_list        # => []           <- not what most people expect
photo.all_tags_list   # => ["paris", "normandy"]
```

The same split applies per context: `location_list` excludes owned tags, `all_locations_list`
includes them. If every tag on a record is applied by a tagger, `tag_list` will always look empty.

So: use `all_*_list` to display what a record is tagged with, and `*_list` only when you
specifically mean the unowned tags.

## Reading owned tags

```ruby
photo.locations_from(user)              # => ["paris", "normandy"]
photo.owner_tags_on(user, :locations)   # => [#<MakeTaggable::Tag name: "paris">, ...]
photo.owner_tags_on(nil, :locations)    # => every tag on the photo, owned or not

user.owned_taggings
user.owned_tags
```

Find records by who tagged them:

```ruby
Photo.tagged_with("paris", on: :locations, owned_by: user)
```

## Owned tags are replaced, not appended

Assigning an owner's tags overwrites everything that owner previously applied in that context:

```ruby
user.tag(photo, with: "paris", on: :locations)
user.tag(photo, with: "normandy", on: :locations)

photo.locations_from(user) # => ["normandy"]   <- "paris" is gone
```

To add to what is already there, read the current list and write it back with the addition:

```ruby
def add_owned_tag(photo, user, tag)
  current = photo.locations_from(user)
  user.tag(photo, with: (current + [tag]).join(", "), on: :locations)
  photo.save
end
```

And to remove one:

```ruby
def remove_owned_tag(photo, user, tag)
  current = photo.locations_from(user)
  user.tag(photo, with: (current - [tag]).join(", "), on: :locations)
  photo.save
end
```

Joining with `", "` matches the default delimiter. If you have configured a different one, use
`MakeTaggable.glue` instead of a literal.

## Ordering

On a model declared with `make_ordered_taggable`, owned tags keep the order they were applied in,
the same as unowned ones. See [contexts.md](contexts.md).
