# Parsers and delimiters

Every string that becomes a tag list goes through a parser. The default splits on commas and
understands quoting.

## The default parser

```ruby
MakeTaggable::DefaultParser.new("One , Two,  Three").parse
# => ["One", "Two", "Three"]
```

A tag containing the delimiter can be quoted, with single or double quotes:

```ruby
MakeTaggable::DefaultParser.new('"Ruby, Rails", Hotwire').parse
# => ["Ruby, Rails", "Hotwire"]
```

`TagList#to_s` quotes on the way back out, so a list survives a round trip through a text field:

```ruby
MakeTaggable::TagList.new("Round", "Square,Cube").to_s
# => 'Round, "Square,Cube"'
```

## Delimiters

The delimiter defaults to `","`. Set one, or several:

```ruby
MakeTaggable.delimiter = ";"
MakeTaggable.delimiter = [",", "|", ";"]
```

**Delimiters are literal strings.** Regular expression metacharacters are escaped for you, so
`"|"`, `"."` and `"("` all mean themselves:

```ruby
MakeTaggable.delimiter = [",", "|"]
MakeTaggable::DefaultParser.new("a|b,c").parse # => ["a", "b", "c"]
```

> **Changed in 1.0.** Delimiters used to be interpolated into a pattern unescaped, which meant you
> had to pass `'\|'` to split on a pipe, and a `"."` delimiter silently matched every character and
> discarded the whole list. If you are passing pre-escaped delimiters, unescape them.

`MakeTaggable.delimiter=` is deprecated in favour of a parser, and warns when Active Record has a
logger. It still works, and reading `MakeTaggable.delimiter` is not deprecated.

Related: `MakeTaggable.glue` is what tags are joined with for display. It is the first configured
delimiter, with a trailing space added if it has none, which is why a comma delimiter renders as
`"one, two"`.

## Writing a parser

Subclass `MakeTaggable::GenericParser` and implement `parse`, returning a `TagList`. The raw input
is in `@tag_list`.

```ruby
class PipeParser < MakeTaggable::GenericParser
  def parse
    MakeTaggable::TagList.new.tap do |tag_list|
      tag_list.add @tag_list.split("|")
    end
  end
end
```

Use it for one call:

```ruby
user.tag_list.add("north|west", parser: PipeParser)
```

For one list:

```ruby
user.tag_list.parser = PipeParser
user.tag_list.add("north|west")
```

Or everywhere:

```ruby
MakeTaggable.default_parser = PipeParser
```

The global setting is what `tag_list=` uses, so it is the only one of the three that changes how
assignment behaves:

```ruby
MakeTaggable.default_parser = PipeParser
user.tag_list = "east|south"
user.tag_list # => ["east", "south"]
```

`GenericParser` is itself a working parser — it splits on commas, ignoring surrounding whitespace
and empty entries — so subclass it when you want a different format, and use it directly when you
want comma splitting without the quoting rules.

## What happens after parsing

Whatever a parser returns is cleaned before it is stored: entries are converted to strings,
stripped of surrounding whitespace, and blanks and duplicates are dropped. Two settings also apply
here — `force_lowercase` and `force_parameterize` — see [configuration.md](configuration.md).

Duplicate detection follows `strict_case_match`: with it off, `"Ruby"` and `"ruby"` are the same
tag; with it on, they are two.
