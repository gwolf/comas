class AdminTasks < ActiveRecord::Migration
  def self.up
    create_table :admin_tasks do |t|
      t.column :name, :string, :null => false
      t.column :sys_name, :string, :null => false
    end
    add_index tbl, :name, :unique => true
    add_index tbl, :sys_name, :unique => true

    create_habtm :admin_tasks, :people

    [['people_adm', 'Attendee administration'],
     ['conferences_adm', 'Conferences administration'],
     ['academic_adm', 'Academic committee'],
     ['attendance_adm', 'Attendance tracking'],
     ['sys_conf_adm', 'System configuration']
    ].each do |at|
      AdminTask.new(:sys_name => at[0], name => at[1]).save!
    end
  end

  def self.down
    drop_habtm :admin_tasks, :people
    drop_table :admin_tasks
  end
end
