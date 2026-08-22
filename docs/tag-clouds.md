# Tag clouds

A tag cloud sizes each tag by how often it is used. MakeTaggable gives you the counts and a helper
that maps them onto CSS classes.

## Getting the counts

```ruby
class BooksController < ApplicationController
  def tag_cloud
    @tags = Book.tag_counts_on(:genres)
  end
end
```

`tag_counts_on` returns tags carrying a `count` attribute. Limit it to the tags worth showing:

```ruby
@tags = Book.all_tag_counts(on: :genres, at_least: 3, limit: 50, order: "count desc")
```

Counts also work per record and per association:

```ruby
book.tag_counts_on(:genres)
user.books.tag_counts_on(:genres)
```

## The helper

`MakeTaggable::TagsHelper` is mixed into Action View automatically, so `tag_cloud` is available in
any view. It yields each tag with the CSS class matching its frequency, smallest class first:

```erb
<% tag_cloud(@tags, %w[cloud1 cloud2 cloud3 cloud4]) do |tag, css_class| %>
  <%= link_to tag.name, books_path(tag: tag.name), class: css_class %>
<% end %>
```

```css
.cloud1 { font-size: 1.0em; }
.cloud2 { font-size: 1.2em; }
.cloud3 { font-size: 1.4em; }
.cloud4 { font-size: 1.6em; }
```

The classes are spread across the range between the least and most used tag in the set you pass, so
the same tag can land in a different band depending on what it is shown alongside.

Two things to know:

- `tag_cloud` requires a block, and returns an empty array without calling it when `@tags` is empty.
- It reads `taggings_count`, not the `count` attribute from the query. That means it reflects how
  often a tag is used **overall**, not how often within the scope you counted. For a cloud of one
  user's tags, sizing by global popularity is usually not what you want — build the markup yourself
  from `tag.count` in that case:

```erb
<% max = @tags.map(&:count).max.to_f %>
<% @tags.each do |tag| %>
  <%= link_to tag.name, books_path(tag: tag.name),
        style: "font-size: #{1.0 + (tag.count / max)}em" %>
<% end %>
```

## Using it outside Action View

Include the module wherever you need it:

```ruby
module PostsHelper
  include MakeTaggable::TagsHelper
end
```
