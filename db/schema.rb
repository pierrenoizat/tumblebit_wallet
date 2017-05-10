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

ActiveRecord::Schema.define(version: 20170430122614) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "clients", force: :cascade do |t|
    t.string   "email",                  default: "", null: false
    t.string   "encrypted_password",     default: "", null: false
    t.string   "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer  "sign_in_count",          default: 0,  null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.inet     "current_sign_in_ip"
    t.inet     "last_sign_in_ip"
    t.datetime "created_at",                          null: false
    t.datetime "updated_at",                          null: false
  end

  add_index "clients", ["email"], name: "index_clients_on_email", unique: true, using: :btree
  add_index "clients", ["reset_password_token"], name: "index_clients_on_reset_password_token", unique: true, using: :btree

  create_table "payment_requests", force: :cascade do |t|
    t.string   "title"
    t.string   "tumbler_public_key"
    t.datetime "expiry_date"
    t.string   "r"
    t.datetime "created_at",                      null: false
    t.datetime "updated_at",                      null: false
    t.string   "aasm_state"
    t.integer  "real_indices",       default: [],              array: true
    t.text     "beta_values",        default: [],              array: true
    t.text     "c_values",           default: [],              array: true
    t.text     "epsilon_values",     default: [],              array: true
    t.string   "key_path"
    t.string   "y"
    t.string   "solution"
  end

  create_table "payments", force: :cascade do |t|
    t.string   "title"
    t.string   "tumbler_public_key"
    t.datetime "expiry_date"
    t.string   "y"
    t.datetime "created_at",                      null: false
    t.datetime "updated_at",                      null: false
    t.text     "beta_values",        default: [],              array: true
    t.text     "ro_values",          default: [],              array: true
    t.text     "k_values",           default: [],              array: true
    t.text     "c_values",           default: [],              array: true
    t.text     "h_values",           default: [],              array: true
    t.string   "aasm_state"
    t.string   "key_path"
    t.integer  "real_indices",       default: [],              array: true
    t.text     "r_values",           default: [],              array: true
    t.string   "solution"
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

  create_table "puzzles", force: :cascade do |t|
    t.integer  "script_id"
    t.text     "y"
    t.text     "encrypted_signature"
    t.datetime "created_at",                       null: false
    t.datetime "updated_at",                       null: false
    t.text     "real_indices",        default: [],              array: true
    t.text     "beta_values",         default: [],              array: true
    t.text     "r"
    t.text     "escrow_txid"
    t.string   "tumbler_public_key"
    t.datetime "expiry_date"
    t.integer  "escrow_amount"
    t.string   "alice_public_key"
    t.string   "bob_public_key"
    t.text     "fake_indices",        default: [],              array: true
  end

  create_table "scripts", force: :cascade do |t|
    t.string   "title"
    t.text     "text"
    t.datetime "created_at",                  null: false
    t.datetime "updated_at",                  null: false
    t.datetime "expiry_date"
    t.integer  "category"
    t.text     "contract"
    t.integer  "user_id"
    t.string   "refund_address"
    t.integer  "client_id"
    t.string   "tumbler_key"
    t.string   "bob_public_key"
    t.integer  "escrow_amount"
    t.string   "escrow_txid"
    t.string   "real_indices",   default: [],              array: true
    t.text     "r"
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
