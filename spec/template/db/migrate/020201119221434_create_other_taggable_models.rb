class CreateOtherTaggableModels < ActiveRecord::Migration[5.2]
  def change
    create_table :other_taggable_models do |t|
      t.column :name, :string
      t.column :type, :string
    end
  end
end
