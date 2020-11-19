# This migration comes from make_taggable_engine (originally 1)
class CreateMakeTaggableTags < ActiveRecord::Migration[6.0]
  def change
    create_table MakeTaggable.tags_table do |t|
      t.string :name
      t.integer :taggings_count, default: 0

      t.timestamps
    end
  end
end
