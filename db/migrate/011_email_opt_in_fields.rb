class EmailOptInFields < ActiveRecord::Migration
  def self.up
    add_column :people, :ok_conf_mails, :boolean, :default => false
    add_column :people, :ok_general_mails, :boolean, :default => false
  end

  def self.down
    remove_column :people, :ok_general_mails
    remove_column :people, :ok_conf_mails
  end
end
