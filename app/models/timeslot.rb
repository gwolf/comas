class Timeslot < ActiveRecord::Base
  belongs_to :room
  has_many :proposals
  has_many :attendances
  has_and_belongs_to_many :prop_types

  validates_presence_of :start_time
  validates_presence_of :room_id
  validates_associated :room
end
