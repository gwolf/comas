class Proposal < ActiveRecord::Base
  New, Pending, Rejected, Accepted = 1, 2, 3, 4
  Status = {New => _('New'), Pending => _('Details pending'),
    Rejected => _('Rejected'), Accepted => _('Accepted')}
  acts_as_magic_model
  has_many :authorships, :dependent => :destroy, :order => :position
  has_many :people, :through => :authorships, :order => 'authorships.position'
  has_many :documents, :dependent => :destroy
  belongs_to :prop_type
  belongs_to :timeslot
  belongs_to :conference

  validates_presence_of :title
  validates_presence_of :prop_type_id
  validate :default_status_if_empty
  validates_presence_of :conference_id
  validates_uniqueness_of :timeslot_id, :allow_nil => true
  validates_associated :prop_type, :timeslot, :conference
  validate_on_create :in_conference_cfp_period
  validate_on_update :dont_change_conference

  def self.core_attributes
    %w(abstract conference_id created_at id prop_type_id status timeslot_id
       title updated_at).map do |attr|
      self.columns.select{|col| col.name == attr}[0]
    end
  end
  def core_attributes; self.class.core_attributes; end

  # Returns a list of any user-listable attributes that are not part of the
  # base Proposal data
  def self.extra_listable_attributes
    self.columns - self.core_attributes
  end
  def extra_listable_attributes; self.class.extra_listable_attributes; end

  def scheduled?
    ! self.timeslot.empty?
  end

  def accepted?
    self.status == Status[Accepted]
  end

  def publicly_showable?
    return true if self.conference.public_proposals? or
      self.accepted?
  end

  def status_name
    Status[self.status]
  end

  protected
  def default_status_if_empty
    self.status ||= Status[New]
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
    prev_state = self.class.find_by_id(self.id) or
      return true # Don't barf when we are deleting the proposal
    return true if self.conference_id == prev_state.conference_id
    self.errors.add(:conference_id,
                    _('An already submitted proposal can not be moved ' +
                      'to a different conference'))
    false
  end
end
