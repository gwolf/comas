class Proposal < ActiveRecord::Base
  acts_as_magic_model
  has_many :authorships, :dependent => :destroy
  has_many :people, :through => :authorships
  has_many :documents, :dependent => :destroy
  belongs_to :prop_type
  belongs_to :prop_status
  belongs_to :timeslot
  belongs_to :conference

  validates_presence_of :title
  validates_presence_of :prop_type_id
  validates_presence_of :prop_status_id
  validates_presence_of :conference_id
  validates_associated :prop_type, :prop_status, :timeslot, :conference

  def scheduled?
    ! self.timeslot.empty?
  end
end
