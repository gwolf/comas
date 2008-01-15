class CreateProposals < ActiveRecord::Migration
  def self.up
    create_catalogs :prop_types, :prop_statuses

    create_table :proposals do |t|
      t.column :title, :string, :null => false
      t.column :abstract, :text

      t.column :created_at, :timestamp
      t.column :updated_at, :timestamp
    end

    add_reference(:proposals, :prop_types, :null => false)
    add_reference(:proposals, :prop_statuses, :null => false, :default => 1)

    add_index :proposals, :prop_type_id
    add_index :proposals, :prop_status_id

    create_table :authorships do |t|
      t.column :position, :integer
    end

    add_reference(:authorships, :people, :null => false)
    add_reference(:authorships, :proposals, :null => false)

    add_index :authorships, [:person_id, :proposal_id], :unique => true
    add_index :authorships, :proposal_id
    add_index :authorships, :person_id
  end

  def self.down
    drop_table :authorships
    drop_table :proposals

    drop_catalogs :prop_types, :prop_statuses
  end

end
