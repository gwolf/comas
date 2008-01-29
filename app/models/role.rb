class Role < ActiveRecord::Base
  include Catalog
  has_and_belongs_to_many :people
  has_and_belongs_to_many :admin_tasks
  translates :name
end
