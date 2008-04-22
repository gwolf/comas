class Conference < ActiveRecord::Base
  has_many :timeslots
  has_many :proposals
  has_many :conference_logos
  has_and_belongs_to_many :people

  validates_presence_of :name
  validates_uniqueness_of :name
  validates_presence_of :descr
  validate :dates_are_correct

  def accepts_registrations?
    (reg_open_date || Date.today) <= Date.today and
    (reg_close_date || finishes || Date.today) >= Date.today
  end

  def accepts_proposals?
    return false if cfp_open_date.nil? and cfp_close_date.nil?
    (cfp_open_date || Date.today) <= Date.today and
      Date.today <= (cfp_close_date || begins || Date.today)
  end

  protected
  def dates_are_correct
    errors.add(:begins, _("%{fn} can't be blank")) if begins.nil? 
    errors.add(:finishes, _("%{fn} can't be blank")) if finishes.nil? 

    dates_in_order?(begins, finishes) or
      errors.add(:begins, _('Conference must end after its start date'))

    dates_in_order?(cfp_open_date, cfp_close_date) or
      errors.add(:cfp_open_date, _('Call for papers must end after its ' +
                                   'start date'))
    dates_in_order?(cfp_close_date, begins) or
      errors.add(:cfp_close_date, _('Call for papers must finish before ' +
                                    'the conference begins'))

    dates_in_order?(reg_open_date, reg_close_date) or
      errors.add(:reg_open_date, _('Registration must end after its ' +
                                   'start date'))
    dates_in_order?(reg_close_date, finishes) or
      errors.add(:reg_close_date, _('Registration must finish before the ' +
                                    'conference ends'))
  end

  def in_period?(start, finish)
    # If either start or finish dates are not defined, behave as an open
    # lapse for this comparison
    start ||= Date.today
    finish ||= Date.today
    Date.today.between?(start, finish)
  end

  def dates_in_order?(date1, date2)
    return true if date1.nil? or date2.nil? or date2 >= date1
    false
  end
end
