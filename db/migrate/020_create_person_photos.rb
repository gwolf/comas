class CreatePersonPhotos < ActiveRecord::Migration
  def self.up
    create_table :person_photos do |t|
      t.binary :data
      t.integer :width
      t.integer :height
      t.timestamps
    end
    add_reference :person_photos, :people, :null => false
    add_index :person_photos, :person_id
  end

  def self.down
    drop_table :person_photos
  end
end
