class Role < ActiveRecord::Base
  acts_as_catalog
  has_and_belongs_to_many :people
  has_and_belongs_to_many :admin_tasks
  translates :name
end
