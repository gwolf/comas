class Timeslot < ActiveRecord::Base
  belongs_to :room
  belongs_to :conference
  has_many :proposals
  has_many :attendances
  has_and_belongs_to_many :prop_types

  validates_presence_of :start_time
  validates_presence_of :room_id
  validates_presence_of :conference_id
  validates_associated :room, :conference
end
