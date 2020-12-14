class CreateUntaggableModels < ActiveRecord::Migration[4.2]
  def change
    create_table :untaggable_models do |t|
      t.column :taggable_model_id, :integer
      t.column :name, :string
    end
  end
end
