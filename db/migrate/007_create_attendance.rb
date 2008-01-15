class CreateAttendance < ActiveRecord::Migration
  def self.up
    create_catalogs :rooms

    create_table :timeslots do |t|
      t.column :start_time, :timestamp
      t.column :tolerance_pre, :interval
      t.column :tolerance_post, :interval
    end
    add_reference :timeslots, :rooms

    add_reference :proposals, :timeslots

    create_habtm :timeslots, :prop_types

    create_table :attendances do |t|
      t.column :created_at, :timestamp
    end
    add_reference :attendances, :people, :null => false
    add_reference :attendances, :timeslots, :null => false
    add_index :attendances, :person_id
    add_index :attendances, [:person_id, :timeslot_id], :unique => true
  end

  def self.down
    
    drop_table :attendances
    drop_habtm :timeslots, :prop_types
    remove_reference :proposals, :timeslots
    drop_table :timeslots
    drop_catalogs :rooms
  end
end
