class InviteOnlyConference < ActiveRecord::Migration
  class Conference < ActiveRecord::Base; end

  def self.up
    add_column :conferences, :invite_only, :boolean, :default => false
    Conference.find(:all).map {|c| c.invite_only = true; c.save}

    # Ugh, real_fk does not implement pointing a reference at a table
    # with a different name. And just renaming it leaves us with a
    # collision when it comes to the constraint's name. Will be fixed
    # at some point in real_fk. Meanwhile... bear with me :-/
    # sender_id and claimer_id should be made into add_reference
    create_table :conf_invites do |t|
      t.column :firstname, :string
      t.column :famname, :string
      t.column :email, :string, :null => false
      t.column :link, :string, :null => false
      t.column :sender_id, :integer, :null => false
      t.column :claimer_id, :integer
    end
    add_reference :conf_invites, :conferences, :null => false

    execute "ALTER TABLE conf_invites ADD CONSTRAINT " +
      "conf_invites_sender_id_fkey FOREIGN KEY (sender_id) " <<
      "REFERENCES people(id) ON DELETE CASCADE"
    execute "ALTER TABLE conf_invites ADD CONSTRAINT " +
      "conf_invites_claimer_id_fkey FOREIGN KEY (claimer_id) " <<
      "REFERENCES people(id) ON DELETE CASCADE"

    add_index :conf_invites, :link, :unique => true
  end

  def self.down
    drop_table :conf_invites
    remove_column :conferences, :invite_only
  end
end
