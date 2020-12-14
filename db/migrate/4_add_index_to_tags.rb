class AddIndexToTags < ActiveRecord::Migration[4.2]
  def change
    add_index MakeTaggable.tags_table, :name, unique: true
  end
end
