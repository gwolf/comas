class Proposal < ActiveRecord::Base
  acts_as_magic_model
  has_many :authorships, :dependent => :destroy, :order => :position
  has_many :people, :through => :authorships, :order => 'authorships.position'
  has_many :documents, :dependent => :destroy
  belongs_to :prop_type
  belongs_to :prop_status
  belongs_to :timeslot
  belongs_to :conference

  validates_presence_of :title
  validates_presence_of :prop_type_id
  validate :default_status_if_empty
  validates_presence_of :conference_id
  validates_uniqueness_of :timeslot_id, :allow_nil => true
  validates_associated :prop_type, :prop_status, :timeslot, :conference
  validate_on_create :in_conference_cfp_period
  validate_on_update :dont_change_conference

  def scheduled?
    ! self.timeslot.empty?
  end

  def accepted?
    self.prop_status == PropStatus.accepted
  end

  protected
  def default_status_if_empty
    self.prop_status ||= PropStatus.default
  end

  def in_conference_cfp_period
    return true if self.conference and self.conference.accepts_proposals?
    self.errors.add(:conference_id,
                    _('Call for papers period for this conference is ' +
                      'not current'))
    false
  end

  # A proposal should not be moved between different conferences
  def dont_change_conference
    prev_state = self.class.find_by_id(self.id)
    return true if self.conference_id == prev_state.conference_id
    self.errors.add(:conference_id,
                    _('An already submitted proposal can not be moved ' +
                      'to a different conference'))
    false
  end
end
