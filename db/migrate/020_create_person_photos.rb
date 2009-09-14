class CreatePhotos < ActiveRecord::Migration
  def self.up
    create_table :photos do |t|
      t.binary :data
      t.integer :width
      t.integer :height
      t.timestamps
    end
    add_reference :photos, :people, :null => false
    add_index :photos, :person_id
  end

  def self.down
    drop_table :photos
  end
end
