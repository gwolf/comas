#:title: Extended migrations
#
# This library extends ActiveRecord::Migration with some commonly used
# functionality in, easily grouped, aiming at keeping your migrations
# short and easy to understand.
#
# = Catalogs
# 
# A catalog is defined as a table with only a +name+ column of
# +string+ type, and with a unique index on it (this means, does not
# allow for duplicate values). A catalog should have a model like the
# following:
# 
#   def Mytable < ActiveRecord::Base
#     belongs_to :some_other_table
#     validates_presence_of :name
#     validates_uniqueness_of :name
#   end

class ActiveRecord::Migration 
  # Specify the list of catalogs which will be created/destroyed when this
  # migration is run:
  #
  #   class CreatePeople < ActiveRecord::Migration
  #     self.include_catalogs [:countries, :person_types]
  #     (...)
  #   end
  def self.include_catalogs(list)
    @@catalogs = list
  end

  # Creates the catalogs specified in include_catalogs. This method
  # will usually be the first thing you call in +self.up+:
  #
  #   def self.up
  #     self.create_catalogs
  #     ...
  #   end
  # 
  # You must either specify the list of catalogs to be created with
  # include_catalogs or include it in the create_catalogs call - The
  # first way is preferred.
  def self.create_catalogs(list=nil)
    list ||= @@catalogs
    list.each do |tbl|
      warn "Creando tabla: #{tbl}"
      create_table tbl do |t|
        t.column :name, :string, :null => false
      end
      add_index tbl, [:name], :unique => true
    end
  end

  # Destroys the catalogs specified in include_catalogs. This method
  # will usually be the last thing you call in +self.down+:
  #
  #   def self.up
  #     ...
  #     self.drop_catalogs
  #   end
  # 
  # You must either specify the list of catalogs to be destroyed with
  # include_catalogs or include it in the drop_catalogs call - The
  # first way is preferred.
  def self.drop_catalogs(list=nil)
    list ||= @@catalogs
    list.each do |tbl|
      warn "Creando tabla: #{tbl}"
      drop_table tbl
    end
  end
end
