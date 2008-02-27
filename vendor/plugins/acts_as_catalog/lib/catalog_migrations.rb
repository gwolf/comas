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
module GWolf
  module UNAM #:nodoc:
    module CatalogMigrations #:nodoc:

      def self.append_features(base)
        super

        # Creates the catalogs specified in include_catalogs. This method
        # will usually be the first thing you call in self.up:
        #
        #   def self.up
        #     create_catalogs :countries, :states
        #     ...
        #   end
        def create_catalogs(*catalogs)
          catalogs.each do |tbl|
            create_table tbl do |t|
              t.column :name, :string, :null => false
            end
            add_index tbl, :name, :unique => true
          end
        end

        # Destroys the catalogs specified in include_catalogs. This method
        # will usually be the last thing you call in self.down:
        #
        #   def self.up
        #     ...
        #     drop_catalogs :states, :countries
        #   end
        def drop_catalogs(*catalogs)
          catalogs.flatten.each do |tbl|
            columns = self.columns(tbl).map {|c| c.name}
            if columns.size != 2 and (columns - ['id','name']).size != 0
              raise ArgumentError, "#{tbl} is not a regular catalog - Not dropping"
            end
            drop_table tbl
          end
        end

      end

    end
  end
end
