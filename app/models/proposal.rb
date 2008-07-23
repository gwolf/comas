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
  validates_presence_of :prop_status_id
  validates_presence_of :conference_id
  validates_associated :prop_type, :prop_status, :timeslot, :conference
  validate_on_create :in_conference_cfp_period
  validate_on_update :dont_change_conference

  def scheduled?
    ! self.timeslot.empty?
  end

  # Possibly we should use something fixed and reliable instead of a
  # regular catalog here?
  def accepted?
    self.prop_status_id == SysConf.value_for('accepted_prop_status_id').to_i
  end

  # Paginates with the most common options set for a listing which
  # does not thrash the DB
  def self.list_paginator(options={})
    defaults = { :page => 1,
      :per_page => 20,
      :include => [:people, :conference, :prop_type, :prop_status],
      :order => 'title, authorships.position' }
    self.paginate(defaults.merge(options))
  end

  protected
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
