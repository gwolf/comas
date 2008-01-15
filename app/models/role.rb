class Role < ActiveRecord::Base
  validates_presence_of :name
  validates_uniqueness_of :name
  has_and_belongs_to_many :people
  has_and_belongs_to_many :admin_tasks
end
