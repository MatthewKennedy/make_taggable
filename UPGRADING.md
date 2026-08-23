Upgrading MakeTaggable

Only the changes that can ask something of you are listed. Everything else is
in CHANGELOG.md.

--------------------------------------------------------------------------
1.7.0

  Tag lists come back in a stable order

    A list is now ordered by when each tag was applied. Before, an order was
    only applied under make_ordered_taggable, so the database chose -- and on
    PostgreSQL that could differ between calls.

    Nothing to change. If you were sorting a list defensively, you no longer
    need to.

  New: a Tag class of your own

    MakeTaggable.setup { |config| config.tag_class = "MyApp::Tag" }

    Name the class as a String, in an initializer. See docs/configuration.md.

--------------------------------------------------------------------------
1.6.0

  Eager loading tag lists actually works

    Book.includes(:tags).each { |book| book.tag_list }

    used to cost a query per record on top of the preload. It no longer does.
    Nothing to change.

--------------------------------------------------------------------------
1.4.0                                                          ACTION NEEDED

  Tag lists are no longer in as_json

    A tag list is not an Active Record attribute any more, so it is not in
    attributes and not in as_json. This is what stops serialising a
    collection querying once per record.

    If an API response included a tag list, it will stop:

      book.as_json                          # no "tag_list" key
      book.as_json(methods: :tag_list)      # ask for it

    attributes["tag_list"] is gone too -- it always returned nil, while
    tag_list returned the tags. Use tag_list.

    Dirty tracking is unchanged: tag_list_changed?, _was, _change,
    saved_change_to_tag_list? and changes all still work.

    MakeTaggable::Taggable::TagListType is removed. It backed the attribute.

--------------------------------------------------------------------------
1.3.0                                                          ACTION NEEDED

  tagged_with no longer joins the taggings table

    It tests for each tag with an EXISTS subquery instead. That is what stops
    a record being returned once per matching tagging -- a tag applied in two
    contexts used to return the record twice, and .count disagreed with the
    number of records.

    A taggings column is no longer in scope on the relation:

      Book.tagged_with("sci-fi").order("taggings.created_at")            # was fine
      Book.tagged_with("sci-fi").joins(:taggings).order("taggings.created_at")

    Joining brings back one row per tagging, so add .distinct if you want
    records rather than matches.

  Five indexes dropped from taggings

    Migration 7 removes single-column indexes on tag_id, taggable_id,
    taggable_type and tagger_id, plus a duplicate of the tagger pair. Each is
    a leading column of an index that remains, so no query plan changes --
    but every index was maintained on insert.

    It is not applied automatically:

      rails make_taggable_engine:install:migrations

--------------------------------------------------------------------------
1.2.0

  A migration you may want

    Migration 6 adds a partial unique index stopping duplicate unowned
    taggings, which the existing index could not do because it spans the
    nullable tagger columns. Install it the same way. MySQL has no partial
    indexes, so it is a no-op there.

--------------------------------------------------------------------------
1.0.0                                                          ACTION NEEDED

  The declaration methods were renamed

    acts_as_taggable                    ->  make_taggable
    acts_as_taggable_on :skills         ->  make_taggable :skills
    acts_as_ordered_taggable            ->  make_ordered_taggable
    acts_as_ordered_taggable_on :skills ->  make_ordered_taggable :skills

  Delimiters are literal strings

    A delimiter is no longer interpolated into a pattern unescaped, so it no
    longer needs escaping by hand:

      MakeTaggable.delimiter = '\|'   ->   MakeTaggable.delimiter = "|"

  make_taggable with no arguments tags on :tags

    It previously added no contexts at all, despite the documentation.

  Minimum versions are Ruby 3.2 and Active Record 7.2
