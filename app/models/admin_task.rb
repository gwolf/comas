class AdminTask < ActiveRecord::Base
  acts_as_catalog
  has_and_belongs_to_many :people
  validates_presence_of :sys_name
  validates_uniqueness_of :sys_name
end
