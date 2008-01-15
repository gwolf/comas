#:title: Extended migrations
#
# This library extends the base Rails ActiveRecord::Migration with some 
# commonly used functionality in, easily grouped, aiming at keeping your 
# migrations short and easy to understand.
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
#
# = References
# 
# Rails is built upon a "dumb database" concept. Rails assumes the database
# will not force restrictions upon the user - i.e. that the model validators
# are all there is. But I disagree ;-)
#
# So, if you want to create a relation field, properly acting as a foreign
# key and refering to another table, instead of doing it via the 
# ActiveRecord::ConnectionAdapters::TableDefinition#column (or even 
# ActiveRecord::ConnectionAdapters::TableDefinition#references) methods,
# declare them this way:
#
#   def self.up
#     create_table :proposals do |t|
#       (...)
#     end
#   end
#   add_reference(:proposals, :prop_types)
#   add_reference(:proposals, :prop_statuses, :null => false, :default => 1)
#
# The corresponding fields (+prop_type_id+ and +prop_status_id+, respectively) 
# will be created, and the foreign key will be set.
module ActiveRecord
  module ConnectionAdapters # :nodoc:
    module SchemaStatements
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

      # Adds a belongs_to relation from the first table to the second one, creating
      # the foreign key, and creating the fields in the first table corresponding
      # to what Rails expects them to be called. 
      #
      # The received options will be passed on to the add_column call.
      def add_reference(from, dest, options = {})
        fieldname = fldname(dest)
        
        add_column(from, fieldname, :integer, options)
        
        if ActiveRecord::Base.connection.adapter_name == 'PostgreSQL'
          execute "ALTER TABLE #{from} ADD CONSTRAINT " <<
            "#{from}_#{fieldname}_fkey FOREIGN KEY (#{fieldname}) " <<
            "REFERENCES #{dest}(id) ON DELETE RESTRICT"
        end
      end

      def remove_reference(from, dest)
        remove_column from, fldname(dest)
      end

      # Creates a HABTM join-table between two given tables, so they can be 
      # linked with a has_and_belongs_to_many declaration in the model.
      #
      # Three indexes will be created for the table: A unique index, ensuring
      # only one relation is created between any two given records, and two
      # regular indexes, to ensure speedy lookups.
      def create_habtm(first, second)
        first, second = second, first if first.to_s > second.to_s 
        first_fld = fldname(first)
        second_fld = fldname(second)
        join_tbl = "#{first}_#{second}"

        create_table(join_tbl, :id => false) {}

        add_reference join_tbl, first 
        add_reference join_tbl, second

        add_index join_tbl, first_fld
        add_index join_tbl, second_fld
        add_index join_tbl, [first_fld, second_fld], :unique => true
      end

      # Drops a HABTM join-table between the two given tables.
      def drop_habtm(first, second)
        first, second = second, first if first.to_s > second.to_s 
        drop_table "#{first}_#{second}"
      end

      private
      #:nodoc:
      def fldname(tbl)
        "#{tbl.to_s.singularize}_id"
      end
    end
  end
end
