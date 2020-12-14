class CreateNonStandardIdTaggableModels < ActiveRecord::Migration[4.2]
  def change
    create_table :non_standard_id_taggable_models, primary_key: "an_id" do |t|
      t.column :name, :string
      t.column :type, :string
    end
  end
end
