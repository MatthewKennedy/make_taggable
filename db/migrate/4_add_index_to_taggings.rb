class AddIndexToTaggings < ActiveRecord::Migration[6.0]
  def change
    add_index :taggings, :taggable_id
    add_index :taggings, :tagger_id
    add_index :taggings, :taggable_type
    add_index :taggings, :context
    add_index :taggings, [:tagger_id, :tagger_type]
    add_index :taggings, [:tag_id, :taggable_id, :taggable_type, :context, :tagger_id, :tagger_type], unique: true, name: "taggings_idx"
    add_index :taggings, [:taggable_id, :taggable_type, :context], name: "taggings_taggable_context_idx"
    add_index :taggings, [:taggable_id, :taggable_type, :tagger_id, :context], name: "taggings_idy"
  end
end
