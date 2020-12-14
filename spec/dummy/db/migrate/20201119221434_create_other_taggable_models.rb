class CreateOtherTaggableModels < ActiveRecord::Migration[6.0]
  def change
    create_table :other_taggable_models do |t|
      t.column :name, :string
      t.column :type, :string
    end
  end
end
