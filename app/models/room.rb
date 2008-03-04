class Room < ActiveRecord::Base
  acts_as_catalog
  has_many :timeslots
end
