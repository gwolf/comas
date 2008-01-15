class AdminTasksAndRoles < ActiveRecord::Migration
  def self.up
    create_catalogs :admin_tasks, :roles
    create_habtm :admin_tasks, :roles
    create_habtm :people, :roles
  end

  def self.down
    drop_habtm :admin_tasks, :roles
    drop_habtm :people, :roles
    drop_catalogs :admin_tasks, :roles
  end
end
