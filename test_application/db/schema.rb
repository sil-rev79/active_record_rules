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

ActiveRecord::Schema[7.2].define(version: 2025_07_07_123216) do
  create_table "arr__rule_match_ids", force: :cascade do |t|
    t.integer "rule_id", limit: 4, null: false
    t.integer "rule_match_id", null: false
    t.string "name", null: false
    t.integer "record_id", null: false
    t.index ["rule_id", "name", "record_id", "rule_match_id"], name: "rule_match_ids_uniqueness", unique: true
    t.index ["rule_match_id"], name: "index_arr__rule_match_ids_on_rule_match_id"
  end

  create_table "arr__rule_matches", force: :cascade do |t|
    t.integer "rule_id", limit: 4, null: false
    t.datetime "queued_since"
    t.datetime "running_since"
    t.datetime "failed_since"
    t.json "ids", null: false
    t.json "live_arguments"
    t.json "next_arguments"
    t.boolean "missing_ids", default: true, null: false
    t.index ["missing_ids"], name: "rule_match_missing_ids"
    t.index ["rule_id", "failed_since"], name: "rule_match_failed_since"
    t.index ["rule_id", "ids"], name: "rule_match_uniqueness", unique: true
    t.index ["rule_id", "queued_since"], name: "rule_match_queued_since"
    t.index ["rule_id", "running_since"], name: "rule_match_running_since"
  end

  create_table "items", force: :cascade do |t|
    t.string "name"
    t.integer "price_cents"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "order_discounts", force: :cascade do |t|
    t.string "key"
    t.integer "order_id", null: false
    t.integer "value"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["order_id"], name: "index_order_discounts_on_order_id"
  end

  create_table "order_items", force: :cascade do |t|
    t.integer "order_id"
    t.integer "item_id"
    t.integer "count"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["item_id"], name: "index_order_items_on_item_id"
    t.index ["order_id"], name: "index_order_items_on_order_id"
  end

  create_table "orders", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  add_foreign_key "arr__rule_match_ids", "arr__rule_matches", column: "rule_match_id", on_delete: :cascade
  add_foreign_key "order_discounts", "orders"
  add_foreign_key "order_items", "items"
  add_foreign_key "order_items", "orders"
end
