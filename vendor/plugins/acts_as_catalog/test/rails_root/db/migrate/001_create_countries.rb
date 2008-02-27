class CreateCountries < ActiveRecord::Migration
  def self.up
    create_catalogs :countries
  end
 
  def self.down
    drop_catalogs :countries
  end
end
