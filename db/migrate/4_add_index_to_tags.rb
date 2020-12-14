class AddIndexToTags < ActiveRecord::Migration[6.0]
  def change
    add_index MakeTaggable.tags_table, :name, unique: true
  end
end
