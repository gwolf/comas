class CreateRescueSessions < ActiveRecord::Migration
  def self.up
    create_table :rescue_sessions do |t|
      t.column :link, :string, :null => false
      t.column :created_at, :timestamp
    end
    add_reference(:rescue_sessions, :people, :null => false)
    add_index :rescue_sessions, :link
  end

  def self.down
    drop_table :rescue_sessions
  end
end
