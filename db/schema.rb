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

ActiveRecord::Schema.define(version: 20150628214119) do

  create_table "leaf_nodes", force: :cascade do |t|
    t.string   "name",       limit: 255
    t.decimal  "credit",                 precision: 30, scale: 2
    t.string   "nonce",      limit: 255
    t.integer  "height",     limit: 4
    t.integer  "tree_id",    limit: 4
    t.datetime "created_at",                                      null: false
    t.datetime "updated_at",                                      null: false
    t.integer  "node_id",    limit: 4
    t.string   "leaf_path",  limit: 255
  end

  create_table "nodes", force: :cascade do |t|
    t.string   "left",       limit: 255
    t.string   "right",      limit: 255
    t.string   "node_hash",  limit: 255
    t.integer  "height",     limit: 4
    t.integer  "tree_id",    limit: 4
    t.datetime "created_at",                                      null: false
    t.datetime "updated_at",                                      null: false
    t.decimal  "sum",                    precision: 30, scale: 2
    t.integer  "left_id",    limit: 4
    t.integer  "right_id",   limit: 4
    t.string   "node_path",  limit: 255
  end

  create_table "posts", force: :cascade do |t|
    t.string   "title",        limit: 255
    t.text     "body",         limit: 65535
    t.datetime "published_at"
    t.datetime "created_at",                 null: false
    t.datetime "updated_at",                 null: false
  end

  create_table "products", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "trees", force: :cascade do |t|
    t.string   "name",                   limit: 255
    t.datetime "created_at",                         null: false
    t.datetime "updated_at",                         null: false
    t.integer  "depth",                  limit: 4
    t.integer  "count",                  limit: 4
    t.integer  "error_count",            limit: 4
    t.integer  "height",                 limit: 4
    t.string   "avatar_file_name",       limit: 255
    t.string   "avatar_content_type",    limit: 255
    t.integer  "avatar_file_size",       limit: 4
    t.datetime "avatar_updated_at"
    t.string   "roll_file_name",         limit: 255
    t.string   "roll_content_type",      limit: 255
    t.integer  "roll_file_size",         limit: 4
    t.datetime "roll_updated_at"
    t.string   "json_file_file_name",    limit: 255
    t.string   "json_file_content_type", limit: 255
    t.integer  "json_file_file_size",    limit: 4
    t.datetime "json_file_updated_at"
    t.string   "url",                    limit: 255
    t.string   "compressed",             limit: 255
  end

  create_table "users", force: :cascade do |t|
    t.string   "provider",   limit: 255
    t.string   "uid",        limit: 255
    t.string   "name",       limit: 255
    t.string   "email",      limit: 255
    t.datetime "created_at",             null: false
    t.datetime "updated_at",             null: false
  end

  create_table "visitors", force: :cascade do |t|
    t.string   "email",      limit: 255
    t.string   "name",       limit: 255
    t.datetime "created_at",             null: false
    t.datetime "updated_at",             null: false
  end

end
