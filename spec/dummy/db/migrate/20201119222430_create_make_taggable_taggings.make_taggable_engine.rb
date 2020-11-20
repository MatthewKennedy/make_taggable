# This migration comes from make_taggable_engine (originally 2)
class CreateMakeTaggableTaggings < ActiveRecord::Migration[5.2]
  def change
    create_table MakeTaggable.taggings_table do |t|
      t.references :tag, foreign_key: {to_table: MakeTaggable.tags_table}
      t.references :taggable, polymorphic: true
      t.references :tagger, polymorphic: true
      t.string :context, limit: 128

      t.timestamps
    end
  end
end
