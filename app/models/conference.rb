class Conference < ActiveRecord::Base
  has_many :timeslots, :dependent => :destroy
  has_many :proposals
  has_one :conference_logo, :dependent => :destroy
  has_and_belongs_to_many :people

  validates_presence_of :name
  validates_uniqueness_of :name
  validates_presence_of :descr
  validate :dates_are_correct
  validate :timeslots_during_conference

  #### PENDING: Reimplement :ensure_conference_accepts_registrations
  #### and :dont_unregister_if_has_proposals (that were in
  #### Participation):
  ####
  #### def ensure_conference_accepts_registrations
  ####   if ! self.conference.accepts_registrations?
  ####     self.errors.add(:conference,
  ####                     _('Registrations for this conference are closed'))
  ####     end  
  ####  end
  ####
  #### def dont_unregister_if_has_proposals
  ####   return true if self.person.authorships.select {|author|
  ####     author.proposal.conference_id==self.conference_id}.empty?
  ####   return false
  #### end
  ####
  #### Idea: Don't implement this as a real trigger; allow for
  #### untimely registration/de-registration, _but_ provide a
  #### validated method call that should be invoked by non-admin-level
  #### controllers. That way, an administrator can still perform those
  #### actions. But... Think it over :-)

  # Produce a paginated list of conferences which have not yet
  # finished, ordered by their beginning date (i.e. the closest first)
  # 
  # It can take whatever parameters you would send to a
  # WillPaginate#paginate call.
  def self.upcoming(req={})
    self.paginate(:all,
                  { :conditions => 'finishes >= now()::date', 
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
    p_id = person.is_a?(Fixnum) ? person : person.id
    self.paginate(:all,
                  { :include => :people,
                    :conditions => ['people.id=? and begins > now()', p_id],
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
    p_id = person.is_a?(Fixnum) ? person : person.id
    self.paginate(:all,
                  { :include => :people,
                    :conditions => ['people.id=? and begins < now()', p_id],
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

  # Do we have propsals submitted by a given user? Give back the list
  def proposals_by_person(person)
    person=Person.find_by_id(person) if person.is_a? Fixnum
    self.proposals.select {|p| p.people.include? person}
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
