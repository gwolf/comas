class Conference < ActiveRecord::Base
  has_many :timeslots, :dependent => :destroy
  has_many :proposals
  has_one :conference_logo, :dependent => :destroy
  has_and_belongs_to_many(:people, 
                          :before_add => :ck_accepts_registrations,
                          :before_remove => :dont_unregiser_if_has_proposals)

  validates_presence_of :name
  validates_uniqueness_of :name
  validates_presence_of :descr
  validate :dates_are_correct
  validate :timeslots_during_conference

  # Produce a list of conferences which have not yet finished, ordered
  # by their beginning date (i.e. the closest first)
  # 
  # It can take whatever parameters you would send to a
  # Conference#find call.
  def self.upcoming(req={})
    self.find(:all, { :conditions => 'finishes >= now()::date', 
                :order => :begins}.merge(req))
  end

  # Produce a list of conferences which are in their registration
  # period (this means, for which a person can currently register as
  # an attendee)
  # 
  # It can take whatever parameters you would send to a
  # Conference#find call.
  def self.in_reg_period(req={})
    self.find(:all, { :conditions => 'now()::date BETWEEN ' +
                'COALESCE(reg_open_date, now()::date) AND ' +
                'COALESCE(reg_close_date, finishes, now()::date)',
                :order => :begins}.merge(req))
  end
  
  # Produce a list of conferences which are in their Call For Papers
  # period (this means, for which a person can currently submit a
  # proposal)
  # 
  # It can take whatever parameters you would send to a
  # Conference#find call.
  def self.in_cfp_period(req={})
    self.find(:all, { :conditions => '(cfp_open_date IS NOT NULL OR ' +
                'cfp_close_date IS NOT NULL) AND now()::date BETWEEN ' +
                'COALESCE(cfp_open_date, now()::date) AND ' +
                'COALESCE(cfp_close_date, begins, now()::date)',
                :order => :begins}.merge(req))
  end

  # Produce a list of conferences which have not yet begun, for which
  # the person specified as the first parameter is registered, ordered
  # by their beginning date (i.e. the closest first)
  def self.upcoming_for_person(person)
    p_id = person.is_a?(Fixnum) ? person : person.id
    person.conferences.sort_by {|c| c.begins}.select {|c| c.upcoming?}
  end

  # Produce a list of conferences which already begun (and might have
  # finished), inversely ordered by their beginning date (i.e. most
  # recent first)
  # 
  # It can take whatever parameters you would send to a Person#find
  # call.
  def self.past(req={})
    self.find(:all, 
              { :conditions => 'begins < now()',
                :order => 'begins desc'
              }.merge(req))
  end

  # All of the conferences which have registered timeslots (this
  # means, those conferences for which we might generate attendance
  # lists)
  def self.past_with_timeslots
    self.past(:include => 'timeslots').select {|c| !c.timeslots.empty?}
  end

  # Produce a list of conferences which have already begun (and might
  # have finished) for which the person specified as the first
  # parameter is registered, inversely ordered by their beginning date
  # (i.e. most recent first)
  def self.past_for_person(person)
    p_id = person.is_a?(Fixnum) ? person : person.id
    person.conferences.order_by {|c| c.begins}.select {|c| c.past?}
  end

  # Returns whether this conference's beginning time is still in the
  # future
  def upcoming?
    begins.to_time > Time.now
  end

  # Returns whether this conference's beginning time is in the past
  # (and might have finished)
  def past?
    begins.to_time < Time.now
  end

  # Can people sign up for this conference? This means, are we in the
  # registration period (or is it blank), and the conference has not
  # yet finished?
  def accepts_registrations?
    (reg_open_date || Date.today) <= Date.today and
    (last_reg_date || Date.today) >= Date.today
  end

  # What is the last valid date for registration? This will return
  # reg_close_date if defined, or the conference finish date otherwise
  def last_reg_date
    reg_close_date || finishes 
  end

  # Does this conference accept registering new proposals? This means,
  # does it have a Call For Papers (CFP)? Are we in that period?  
  #
  # If it has a cfp_open_date but not a cfp_close_date, take
  # conference beginning date as a deadline (i.e. no proposals might
  # be submitted once the conference has started)
  def accepts_proposals?
    return false unless !has_cfp?
    Date.today.between?(cfp_open_date || Date.today,
                        last_cfp_date || Date.today)
  end

  # Does this conference have a Call For Papers period? (even if it is
  # not current) 
  def has_cfp?
    return false if cfp_open_date.nil? and cfp_close_date.nil?
    true
  end

  # What is the last valid date for the Call For Papers period? This
  # will return cfp_close_date if defined, or the conference beginning
  # date otherwise
  def last_cfp_date
    cfp_close_date || begins
  end

  # Is this conference taking place now?
  def current?
    Date.today.between?(begins, finishes)
  end

  # Do we have propsals submitted by a given user? Give back the list
  def proposals_by_person(person)
    person=Person.find_by_id(person) if person.is_a? Fixnum
    self.proposals.select {|p| p.people.include? person}
  end

  private
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

  def ck_accepts_registrations(person)
    return true if self.accepts_registrations?
    raise(ActiveRecord::RecordNotSaved,
          _('This conference does not currently accept registrations'))
  end

  def dont_unregister_if_has_proposals(person)
    return true if self.proposals_by_person(person).empty?
    raise(ActiveRecord::RecordNotSaved, 
          _('Cannot remove %s from this conference - Remove or reassign '+
            'his proposals first') % person.name)
  end
end
