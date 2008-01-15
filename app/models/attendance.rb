class Attendance < ActiveRecord::Base
  belongs_to :timeslot
  belongs_to :person

  validates_presence_of :timeslot_id
  validates_presence_of :person_id
  validates_associated :timeslot
  validates_associated :person
end
