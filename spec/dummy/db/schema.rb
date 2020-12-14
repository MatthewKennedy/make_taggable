# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 2020_11_21_222011) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "cache_methods_injected_models", force: :cascade do |t|
    t.string "cached_tag_list"
  end

  create_table "cached_models", force: :cascade do |t|
    t.string "name"
    t.string "type"
    t.string "cached_tag_list"
  end

  create_table "columns_override_models", force: :cascade do |t|
    t.string "name"
    t.string "type"
    t.string "ignored_column"
  end

  create_table "companies", force: :cascade do |t|
    t.string "name"
  end

  create_table "non_standard_id_taggable_models", primary_key: "an_id", force: :cascade do |t|
    t.string "name"
    t.string "type"
  end

  create_table "ordered_taggable_models", force: :cascade do |t|
    t.string "name"
    t.string "type"
  end

  create_table "other_cached_models", force: :cascade do |t|
    t.string "name"
    t.string "type"
    t.string "cached_language_list"
    t.string "cached_status_list"
    t.string "cached_glass_list"
  end

  create_table "other_cached_with_array_models", force: :cascade do |t|
    t.string "name"
    t.string "type"
    t.string "cached_language_list", array: true
    t.string "cached_status_list", array: true
    t.string "cached_glass_list", array: true
  end

  create_table "other_taggable_models", force: :cascade do |t|
    t.string "name"
    t.string "type"
  end

  create_table "taggable_model_with_jsons", force: :cascade do |t|
    t.string "name"
    t.string "type"
    t.json "opts"
  end

  create_table "taggable_models", force: :cascade do |t|
    t.string "name"
    t.string "type"
  end

  create_table "taggings", force: :cascade do |t|
    t.bigint "tag_id"
    t.string "taggable_type"
    t.bigint "taggable_id"
    t.string "tagger_type"
    t.bigint "tagger_id"
    t.string "context", limit: 128
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["context"], name: "index_taggings_on_context"
    t.index ["tag_id", "taggable_id", "taggable_type", "context", "tagger_id", "tagger_type"], name: "taggings_idx", unique: true
    t.index ["tag_id"], name: "index_taggings_on_tag_id"
    t.index ["taggable_id", "taggable_type", "context"], name: "taggings_taggable_context_idx"
    t.index ["taggable_id", "taggable_type", "tagger_id", "context"], name: "taggings_idy"
    t.index ["taggable_id"], name: "index_taggings_on_taggable_id"
    t.index ["taggable_type", "taggable_id"], name: "index_taggings_on_taggable"
    t.index ["taggable_type"], name: "index_taggings_on_taggable_type"
    t.index ["tagger_id", "tagger_type"], name: "index_taggings_on_tagger_id_and_tagger_type"
    t.index ["tagger_id"], name: "index_taggings_on_tagger_id"
    t.index ["tagger_type", "tagger_id"], name: "index_taggings_on_tagger"
  end

  create_table "tags", force: :cascade do |t|
    t.string "name"
    t.integer "taggings_count", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_tags_on_name", unique: true
  end

  create_table "untaggable_models", force: :cascade do |t|
    t.integer "taggable_model_id"
    t.string "name"
  end

  create_table "users", force: :cascade do |t|
    t.string "name"
  end

  add_foreign_key "taggings", "tags"
end
