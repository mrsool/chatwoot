class CreateCompensationCapSettings < ActiveRecord::Migration[7.2]
  def change
    create_table :compensation_cap_settings do |t|
      t.references :account, null: false, index: false
      t.decimal :bad_grade_value_limit, precision: 10, scale: 2
      t.decimal :at_risk_value_limit, precision: 10, scale: 2
      t.decimal :valuable_value_limit, precision: 10, scale: 2
      t.integer :per_order_count_limit
      t.integer :bad_grade_window_count_limit
      t.integer :at_risk_window_count_limit
      t.integer :valuable_window_count_limit
      t.integer :vip_window_count_limit
      t.integer :window_days
      t.bigint :updated_by_id
      t.timestamps
    end

    add_index :compensation_cap_settings, :account_id, unique: true, name: 'index_compensation_cap_settings_on_account_id'
  end
end
