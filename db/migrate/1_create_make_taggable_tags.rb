class CreateMakeTaggableTags < ActiveRecord::Migration[4.2]
  def change
    create_table MakeTaggable.tags_table do |t|
      t.string :name
      t.integer :taggings_count, default: 0

      t.timestamps
    end
  end
end
