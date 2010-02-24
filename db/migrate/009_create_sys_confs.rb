class CreateSysConfs < ActiveRecord::Migration
  def self.up
    create_table :sys_confs do |t|
      t.column :key, :string, :null => false, :unique => true
      t.column :descr, :string
      t.column :value, :string
    end
  end

  def self.down
    drop_table :sys_confs
  end
end
