class CreateAwayReasons < ActiveRecord::Migration[7.2]
  def change
    create_table :away_reasons do |t|
      t.references :account, null: false, index: false
      t.string :name, null: false
      t.boolean :active, null: false, default: true
      t.integer :position, null: false, default: 0
      t.timestamps
    end

    add_index :away_reasons, 'account_id, lower(name)', unique: true, name: 'index_away_reasons_on_account_id_and_lower_name'
  end
end
