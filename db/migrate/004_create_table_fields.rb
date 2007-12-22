class CreateTableFields < ActiveRecord::Migration
  def self.up
    create_table :table_fields do |t|
      t.column :model, :string, :null => false
      t.column :field, :string, :null => false
      t.column :allow_null, :boolean, :default => true
      t.column :valid_regex, :string
      t.column :order, :integer, :default => 0
    end
  end

  def self.down
    drop_table :table_fields
  end
end
