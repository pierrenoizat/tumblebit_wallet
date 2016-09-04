# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20160904144643) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "leaf_nodes", force: :cascade do |t|
    t.string   "name"
    t.decimal  "credit",     precision: 30, scale: 2
    t.string   "nonce"
    t.integer  "height"
    t.integer  "tree_id"
    t.datetime "created_at",                          null: false
    t.datetime "updated_at",                          null: false
    t.integer  "node_id"
    t.string   "leaf_path"
  end

  create_table "nodes", force: :cascade do |t|
    t.string   "left"
    t.string   "right"
    t.string   "node_hash"
    t.integer  "height"
    t.integer  "tree_id"
    t.datetime "created_at",                          null: false
    t.datetime "updated_at",                          null: false
    t.decimal  "sum",        precision: 30, scale: 2
    t.integer  "left_id"
    t.integer  "right_id"
    t.string   "node_path"
  end

  create_table "posts", force: :cascade do |t|
    t.string   "title"
    t.text     "body"
    t.datetime "published_at"
    t.datetime "created_at",   null: false
    t.datetime "updated_at",   null: false
  end

  create_table "products", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "public_keys", force: :cascade do |t|
    t.string   "name"
    t.string   "compressed"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer  "script_id"
  end

  create_table "scripts", force: :cascade do |t|
    t.string   "title"
    t.text     "text"
    t.datetime "created_at",  null: false
    t.datetime "updated_at",  null: false
    t.datetime "expiry_date"
    t.integer  "category"
  end

  create_table "trees", force: :cascade do |t|
    t.string   "name"
    t.datetime "created_at",             null: false
    t.datetime "updated_at",             null: false
    t.integer  "depth"
    t.integer  "count"
    t.integer  "error_count"
    t.integer  "height"
    t.string   "avatar_file_name"
    t.string   "avatar_content_type"
    t.integer  "avatar_file_size"
    t.datetime "avatar_updated_at"
    t.string   "roll_file_name"
    t.string   "roll_content_type"
    t.integer  "roll_file_size"
    t.datetime "roll_updated_at"
    t.string   "json_file_file_name"
    t.string   "json_file_content_type"
    t.integer  "json_file_file_size"
    t.datetime "json_file_updated_at"
    t.string   "url"
    t.string   "compressed"
  end

  create_table "users", force: :cascade do |t|
    t.string   "provider"
    t.string   "uid"
    t.string   "name"
    t.string   "email"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "visitors", force: :cascade do |t|
    t.string   "email"
    t.string   "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

end
