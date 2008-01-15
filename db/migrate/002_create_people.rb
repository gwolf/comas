class CreatePeople < ActiveRecord::Migration
  def self.up
    create_catalogs :person_types

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
    add_reference(:people, :person_types, :null => false)
  end

  def self.down
    drop_table :people

    drop_catalogs :person_types
  end
end
