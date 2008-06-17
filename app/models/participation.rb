class Participation < ActiveRecord::Base
  belongs_to :person
  belongs_to :conference
  belongs_to :participation_type

  validates_presence_of :person_id
  validates_presence_of :conference_id
  validate do |part|
    part.participation_type ||= ParticipationType.default
  end
  validates_associated :person
  validates_associated :conference
  validates_associated :participation_type
  validates_uniqueness_of(:participation_type_id, 
                          :scope => [ :person_id, :conference_id ])
end
