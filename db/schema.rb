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

ActiveRecord::Schema.define(version: 20170917213513) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "payment_requests", id: :serial, force: :cascade do |t|
    t.string "title"
    t.string "tumbler_public_key"
    t.datetime "expiry_date"
    t.string "r"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "aasm_state"
    t.integer "real_indices", default: [], array: true
    t.text "beta_values", default: [], array: true
    t.text "c_values", default: [], array: true
    t.text "epsilon_values", default: [], array: true
    t.string "key_path"
    t.string "solution"
    t.text "z_values", default: [], array: true
    t.text "quotients", default: [], array: true
    t.string "blinding_factor"
    t.string "tx_hash"
    t.integer "index"
    t.integer "amount"
    t.integer "confirmations"
  end

  create_table "payments", id: :serial, force: :cascade do |t|
    t.string "title"
    t.string "tumbler_public_key"
    t.datetime "expiry_date"
    t.string "y"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "beta_values", default: [], array: true
    t.text "k_values", default: [], array: true
    t.text "c_values", default: [], array: true
    t.text "h_values", default: [], array: true
    t.string "aasm_state"
    t.string "key_path"
    t.integer "real_indices", default: [], array: true
    t.text "r_values", default: [], array: true
    t.string "solution"
  end

  create_table "posts", id: :serial, force: :cascade do |t|
    t.string "title"
    t.text "body"
    t.datetime "published_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "products", id: :serial, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "users", id: :serial, force: :cascade do |t|
    t.string "provider"
    t.string "uid"
    t.string "name"
    t.string "email"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "visitors", id: :serial, force: :cascade do |t|
    t.string "email"
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

end
