class Multiconferences < ActiveRecord::Migration
  def self.up
    create_table :conferences do |t|
      t.column :name, :string, :null => false
      t.column :descr, :text, :null => false
      t.column :active, :bool, :default => true, :null => false
      t.column :has_cfp, :bool, :default => false, :null => true
      t.column :homepage, :string
      t.column :cfp_open_date, :date
      t.column :cfp_close_date, :date
      t.column :begins, :date, :null => false
      t.column :finishes, :date, :null => false
    end
    add_index :conferences, :name, :unique => true

    create_table :conference_logos do |t|
      t.column :filename, :string
      t.column :data, :binary
    end
    add_reference :conference_logos, :conferences, :null => false

    add_reference :timeslots, :conferences, :null => false
    add_reference :proposals, :conferences, :null => false
    create_habtm :people, :conferences
  end

  def self.down
    drop_habtm :people, :conferences
    remove_reference :proposals, :conferences
    remove_reference :timeslots, :conferences

    drop_table :conference_logos
    drop_table :conferences
  end
end
