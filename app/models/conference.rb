class Conference < ActiveRecord::Base
  has_many :timeslots
  has_many :proposals
  has_many :conference_logos
  has_and_belongs_to_many :people

  validates_presence_of :name
end
