class PersonType < ActiveRecord::Base
  include Catalog
  has_many :people
  translates :name
end
