# Migrating from acts-as-taggable-on

MakeTaggable began as a fork of
[acts-as-taggable-on](https://github.com/mbleigh/acts-as-taggable-on). The behaviour is largely the
same; the names are not.

## Method names

| acts-as-taggable-on | MakeTaggable |
|---|---|
| `acts_as_taggable` | `make_taggable` |
| `acts_as_taggable_on :skills` | `make_taggable :skills` |
| `acts_as_ordered_taggable` | `make_ordered_taggable` |
| `acts_as_ordered_taggable_on :skills` | `make_ordered_taggable :skills` |
| `acts_as_tagger` | `make_tagger` |

> Versions of MakeTaggable before 1.0 kept the `acts_as_*` names as aliases. They were removed in
> 1.0 — see [UPGRADING.md](../UPGRADING.md).

Everything generated per context is unchanged: `skill_list`, `skills`, `skill_counts`,
`top_skills`, `skills_from`, `find_related_skills` and the rest all keep their names.

## Constants

| acts-as-taggable-on | MakeTaggable |
|---|---|
| `ActsAsTaggableOn::Tag` | `MakeTaggable::Tag` |
| `ActsAsTaggableOn::Tagging` | `MakeTaggable::Tagging` |
| `ActsAsTaggableOn::TagList` | `MakeTaggable::TagList` |
| `ActsAsTaggableOn::GenericParser` | `MakeTaggable::GenericParser` |
| `ActsAsTaggableOn::DefaultParser` | `MakeTaggable::DefaultParser` |
| `ActsAsTaggableOn.setup` | `MakeTaggable.setup` |

Configuration keys are the same. `ActsAsTaggableOn.force_lowercase` becomes
`MakeTaggable.force_lowercase`, and so on — see [configuration.md](configuration.md).

## The database

The schema is compatible: the same `tags` and `taggings` tables, with the same columns. If you are
switching an application over, you do not need to move any data.

Two differences to check before you do:

- **`taggable_type` and `tagger_type` hold class names.** They do not mention either library, so
  they carry across untouched.
- **acts-as-taggable-on's migrations differ in their indexes** depending on which version installed
  them. MakeTaggable's migrations are separate files with their own version numbers, so running
  `rails make_taggable_engine:install:migrations` on a database that already has the tables will try
  to create them again. Skip those migrations, or mark them as run, rather than letting them
  execute.

## Behaviour differences

- **Delimiters are literal strings.** acts-as-taggable-on interpolated the configured delimiter into
  a pattern unescaped, so splitting on `|` meant passing `'\|'`. MakeTaggable escapes for you: pass
  `"|"`. See [parsers.md](parsers.md).
- **`make_taggable` with no arguments tags on `:tags`.** In acts-as-taggable-on, `acts_as_taggable`
  was the no-argument form and `acts_as_taggable_on` took contexts; MakeTaggable uses one method for
  both.
- **Requirements are higher.** Ruby 3.2 and Active Record 7.2, against acts-as-taggable-on's wider
  range.

## What has not changed

The parts people rely on most behave identically: `tagged_with` and all its options, tag ownership
and the rule that `tag_list` excludes owned tags, dirty tracking on `*_list` attributes, cached tag
list columns, the tag cloud helper, and custom parsers.
