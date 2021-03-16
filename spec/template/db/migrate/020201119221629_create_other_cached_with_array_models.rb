class CreateOtherCachedWithArrayModels < ActiveRecord::Migration[5.2]
  def change
    create_table :other_cached_with_array_models do |t|
      t.column :name, :string
      t.column :type, :string
      t.column :cached_language_list, :string, array: true
      t.column :cached_status_list, :string, array: true
      t.column :cached_glass_list, :string, array: true
    end
  end
end
