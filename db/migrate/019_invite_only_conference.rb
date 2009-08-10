class InviteOnlyConference < ActiveRecord::Migration
  class Conference < ActiveRecord::Base; end

  def self.up
    add_column :conferences, :invite_only, :boolean, :default => false
    Conference.find(:all).map {|c| c.invite_only = true; c.save}

    create_table :conf_invites do |t|
      t.column :firstname, :string
      t.column :famname, :string
      t.column :email, :string, :null => false
      t.column :link, :string, :null => false
    end
    add_reference :conf_invites, :conferences, :null => false
    add_reference :conf_invites, :people, :as => 'sender'
    add_reference :conf_invites, :people, :as => 'claimer'

    add_index :conf_invites, :link, :unique => true
  end

  def self.down
    drop_table :conf_invites
    remove_column :conferences, :invite_only
  end
end
