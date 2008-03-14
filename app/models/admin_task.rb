class AdminTask < ActiveRecord::Base
  acts_as_catalog
  has_and_belongs_to_many :people
end
