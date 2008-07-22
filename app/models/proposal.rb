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
  validate_on_create :in_conference_cfp_period

  def scheduled?
    ! self.timeslot.empty?
  end

  # Possibly we should use something fixed and reliable instead of a
  # regular catalog here?
  def accepted?
    self.prop_status_id == SysConf.value_for('accepted_prop_status_id').to_i
  end

  protected
  def in_conference_cfp_period
    return true if self.conference and self.conference.accepts_proposals?
    self.errors.add(:conference_id,
                    _('Call for papers period for this conference is ' +
                      'not current'))
    false
  end
end
