# This migration comes from make_taggable_engine (originally 5)
class AddIndexToTaggings < ActiveRecord::Migration[5.2]
  def change
    add_index MakeTaggable.taggings_table, :taggable_id
    add_index MakeTaggable.taggings_table, :tagger_id
    add_index MakeTaggable.taggings_table, :taggable_type
    add_index MakeTaggable.taggings_table, :context
    add_index MakeTaggable.taggings_table, [:tagger_id, :tagger_type]
    add_index MakeTaggable.taggings_table, [:tag_id, :taggable_id, :taggable_type, :context, :tagger_id, :tagger_type], unique: true, name: "taggings_idx"
    add_index MakeTaggable.taggings_table, [:taggable_id, :taggable_type, :context], name: "taggings_taggable_context_idx"
    add_index MakeTaggable.taggings_table, [:taggable_id, :taggable_type, :tagger_id, :context], name: "taggings_idy"
  end
end
