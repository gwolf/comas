class CreatePeople < ActiveRecord::Migration
  self.include_catalogs [:person_types, :countries]

  def self.up
    self.create_catalogs

    create_table :people do |t|
      t.column :login, :string, :null => false
      t.column :passwd, :string, :null => false
      t.column :firstname, :string, :null => false
      t.column :famname, :string, :null => false

      t.column :email, :string
      t.column :org, :string
      t.column :dept, :string
      t.column :postal_addr, :string
      t.column :fax, :string

      t.column :person_type_id, :integer
      t.column :country_id, :integer

      t.column :pw_salt, :string
      t.column :created_at, :timestamp
      t.column :last_login_at, :timestamp
    end
  end

  def self.down
    drop_table :people

    self.drop_catalogs
  end

end
