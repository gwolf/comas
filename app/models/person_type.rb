class PersonType < ActiveRecord::Base
  acts_as_catalog
  has_many :people
  translates :name
end
