class CreateTranslations < ActiveRecord::Migration
  def self.up
    create_table :translations do |t|
      t.column :base, :string, :null => false
      t.column :lang, :string, :null => false
      t.column :translated, :string
      t.timestamps
    end
    add_index :translations, :base
    add_index :translations, :lang
    add_index :translations, [:base, :lang], :unique => true
  end

  def self.down
    drop_table :translations
  end
end
