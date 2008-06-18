class Conference < ActiveRecord::Base
  has_many :timeslots
  has_many :proposals
  has_one :conference_logo
  has_many :participations
  has_many :people, :through => :participations

  validates_presence_of :name
  validates_uniqueness_of :name
  validates_presence_of :descr
  validate :dates_are_correct
  validate :timeslots_during_conference

  # Produce a paginated list of conferences which have not yet begun,
  # ordered by their beginning date (i.e. the closest first)
  # 
  # It can take whatever parameters you would send to a
  # WillPaginate#paginate call.
  def self.upcoming(req={})
    self.paginate(:all,
                  { :conditions => 'begins > now()', 
                    :order => :begins,
                    :page => 1}.merge(req))
  end

  # Produce a paginated list of conferences which have not yet begun,
  # for which the person specified as the first parameter is
  # registered, ordered by their beginning date (i.e. the closest first)
  # 
  # It can take whatever parameters you would send to a
  # WillPaginate#paginate call.
  def self.upcoming_for_person(person, req={})
    self.paginate(:all,
                  { :joins => 'LEFT OUTER JOIN participations ON ' <<
                    'participations.conference_id = conferences.id',
                    :conditions => ['person_id=? and begins > now()', person],
                    :order => 'begins',
                    :page => 1}.merge(req))
  end

  # Produce a paginated list of conferences which already begun (and
  # have probably finished), inversely ordered by their beginning date
  # (i.e. most recent first)
  # 
  # It can take whatever parameters you would send to a
  # WillPaginate#paginate call.
  def self.past(req={})
    self.paginate(:all, 
                  { :conditions => 'begins < now()',
                    :order => 'begins desc',
                    :page => 1}.merge(req))
  end


  # Produce a paginated list of conferences which have already begun
  # (and have probably finished) for which the person specified as the
  # first parameter is registered, inversely ordered by their
  # beginning date (i.e. most recent first)
  # 
  # It can take whatever parameters you would send to a
  # WillPaginate#paginate call.
  def self.past_for_person(person, req={})
    self.paginate(:all,
                  { :joins => 'LEFT OUTER JOIN participations ON ' <<
                    'participations.conference_id = conferences.id',
                    :conditions => ['person_id=? and begins > now()', person],
                    :order => 'begins',
                    :page => 1}.merge(req))
  end

  # Can people sign up for this conference? This means, are we in the
  # registration period (or is it blank), and the conference has not
  # yet finished?
  def accepts_registrations?
    (reg_open_date || Date.today) <= Date.today and
    (reg_close_date || finishes || Date.today) >= Date.today
  end

  # Does this conference accept registering new proposals? This means,
  # does it have a Call For Papers (CFP)? Are we in that period?  
  #
  # If it has a cfp_open_date but not a cfp_close_date, take
  # conference beginning date as a deadline (i.e. no proposals might
  # be submitted once the conference has started)
  def accepts_proposals?
    return false if cfp_open_date.nil? and cfp_close_date.nil?
    Date.today.between?(cfp_open_date || Date.today,
                        cfp_close_date || begins || Date.today)
  end

  # Is this conference taking place now?
  def current?
    Date.today.between?(begins, finishes)
  end

  protected
  # Verify the submitted dates are coherent (i.e. none of the periods
  # we care about finishes before it begins)
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

  # If we change the beginning/finishing dates for the conference,
  # make sure we don't end up with timeslots outside our dates.
  def timeslots_during_conference
    outside = self.timeslots.reject do |ts| 
      ts.start_time.to_date.between? begins, finishes
    end
    return true if outside.empty?
    errors.add_to_base(_('There are %d timeslots for this conference ' +
                         'outside its time span: %s') % 
                       [outside.size, 
                        outside.map {|ts| "%s (%s)" % 
                          [ts.start_time, ts.room.name]}.join(', ')])
  end

  # Are the two received dates in chronological order? (If either or
  # both are nil, returns true)
  def dates_in_order?(date1, date2)
    return true if date1.nil? or date2.nil? or date2 >= date1
    false
  end
end
