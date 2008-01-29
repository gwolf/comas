class Room < ActiveRecord::Base
  include Catalog
  has_many :timeslots
end
