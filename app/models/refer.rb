class Refer < ActiveRecord::Base
  acts_as_catalog
  has_many :people
end
