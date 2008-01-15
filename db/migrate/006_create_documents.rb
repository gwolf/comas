class CreateDocuments < ActiveRecord::Migration
  def self.up
    create_table :documents do |t|
      t.column :filename, :string
      t.column :descr, :string
      t.column :content_type, :string
      t.column :data, :binary
      t.timestamps
    end
    add_reference :documents, :proposals, :null => false
    add_index :documents, :proposal_id
  end

  def self.down
    drop_table :documents
  end
end
