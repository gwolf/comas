class MinAttendancesForCertif < ActiveRecord::Migration
  def self.up
    add_column :conference, :min_attendances, :integer, :default => 0, :null => false
  end
  def self.down
    remove_column :conferences, :min_attendances
  end
end
