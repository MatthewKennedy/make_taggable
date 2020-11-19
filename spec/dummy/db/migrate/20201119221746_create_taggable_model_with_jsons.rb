class CreateTaggableModelWithJsons < ActiveRecord::Migration[6.0]
  def change
    create_table :taggable_model_with_jsons do |t|
      t.column :name, :string
      t.column :type, :string
      t.column :opts, :json
    end
  end
end
