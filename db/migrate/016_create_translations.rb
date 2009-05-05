class AdminTask < ActiveRecord::Base
  has_and_belongs_to_many :people
end
# Person has to be defined so that migrating down when there are
# people with this admin task they are deleted as well
class Person < ActiveRecord::Base
  has_and_belongs_to_many :admin_tasks
end

class CreateTranslations < ActiveRecord::Migration
  def self.up
    create_catalogs :languages

    create_table :translations do |t|
      t.column :base, :string, :null => false
      t.column :translated, :string
      t.timestamps
    end
    add_reference(:translations, :languages, :null => false)
    add_index :translations, :base
    add_index :translations, [:base, :language_id], :unique => true

    AdminTask.new(:name => 'Translation management',
                  :sys_name => 'translation').save!
  end

  def self.down
    AdminTask.find_by_sys_name('translation').destroy
    drop_table :translations
    drop_catalogs :languages
  end
end
