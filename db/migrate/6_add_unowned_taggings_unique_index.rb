class AddUnownedTaggingsUniqueIndex < ActiveRecord::Migration[7.2]
  # taggings_idx spans tagger_id and tagger_type, which are NULL on every
  # tagging nobody owns. SQL compares NULLs as distinct, so that index does not
  # stop two identical unowned taggings -- only the model validation does, and a
  # validation cannot win a race between two concurrent writes.
  #
  # A partial index closes it. MySQL has no partial indexes, so it keeps the
  # validation on its own.
  def change
    return if MakeTaggable::Utils.using_mysql?

    add_index MakeTaggable.taggings_table,
      [:tag_id, :taggable_id, :taggable_type, :context],
      unique: true,
      where: "tagger_id IS NULL",
      name: "taggings_unowned_idx"
  end
end
