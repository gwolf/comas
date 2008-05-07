class CreatePeople < ActiveRecord::Migration
  def self.up
    create_table :people do |t|
      t.column :login, :string, :null => false
      t.column :passwd, :string, :null => false
      t.column :firstname, :string, :null => false
      t.column :famname, :string, :null => false
      t.column :email, :string

      t.column :pw_salt, :string
      t.column :created_at, :timestamp
      t.column :last_login_at, :timestamp
    end
  end

  def self.down
    drop_table :people
  end
end
