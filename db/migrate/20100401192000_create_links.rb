class CreateLinks < ActiveRecord::Migration
  def change
    create_table "common.links" do |t|
      t.integer :organisation_id
      t.integer :user_id
      t.string  :settings
      t.boolean :creator        , default: false
      t.boolean :master_account , default: false

      t.string   :rol           , :limit => 50
      t.boolean  :active        , :default => true

      t.timestamps
    end

    add_index "common.links", :organisation_id
    add_index "common.links", :user_id
  end
end