class AddAwayReasonToAccountUsers < ActiveRecord::Migration[7.2]
  def change
    add_reference :account_users, :away_reason, null: true, index: true,
                                                foreign_key: { to_table: :away_reasons, on_delete: :nullify }

    create_table :agent_availability_events do |t| # rubocop:disable Rails/CreateTableWithTimestamps
      t.bigint :account_id, null: false
      t.bigint :user_id, null: false
      t.integer :status, null: false
      t.bigint :away_reason_id
      t.datetime :changed_at, null: false
    end

    add_index :agent_availability_events, [:account_id, :user_id, :changed_at], name: 'index_agent_availability_events_on_account_user_changed_at'
  end
end
