class CreatePhotos < ActiveRecord::Migration
  def self.up
    create_table :photos do |t|
      t.column :width, :integer
      t.column :height, :integer
      t.column :data, :binary
      t.column :thumb, :binary
      t.timestamps
    end
    add_reference :photos, :people, :null => false
    add_index :photos, :person_id
  end

  def self.down
    drop_table :photos
  end
end
