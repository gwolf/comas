class Conference < ActiveRecord::Base
  acts_as_magic_model
  has_many :timeslots, :dependent => :destroy
  has_many :proposals
  has_many :conf_invites, :dependent => :destroy
  has_one :logo, :dependent => :destroy
  has_and_belongs_to_many(:people,
                          :before_add => :ck_in_reg_period,
                          :before_remove => :dont_unregister_if_has_proposals)

  validates_presence_of :name
  validates_uniqueness_of :name
  validates_presence_of :descr
  validate :ensure_short_name
  validate :dates_are_correct
  validate :timeslots_during_conference
  validate :cfp_data_only_if_manages_proposals
  validate :no_proposals_unless_manages_proposals

  def self.core_attributes
    %w(begins cfp_close_date cfp_open_date descr finishes homepage id
       invite_only manages_proposals name public_proposals reg_close_date
       reg_open_date short_name).map do |attr|
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

  # Returns a hash of catalogs related to this table (where the key is
  # the field name and the value is the related class). Catalogs are
  # attributes whose name ends in _id, and for which there is a
  # suitably named related table with 'id' and 'name' columns.
  def self.catalogs
    Hash[self.column_names.map do |col|
           begin
             if col =~ /(.*)_id$/ and
                 klass = $1.classify.constantize and
                 klass.column_names.include? 'id' and
                 klass.column_names.include? 'name'
               [col, klass]
             end
           rescue NameError
             false
           end
         end.select {|col| col}
        ]
  end

  # Produce a list of conferences which have not yet finished, ordered
  # by their beginning date (i.e. the closest first)
  #
  # It can take whatever parameters you would send to a
  # Conference#find call.
  def self.upcoming(req={})
    self.find(:all, { :conditions => ['finishes >= ?', Date.today],
                :order => :begins}.merge(req))
  end

  # Produce a list of conferences which are in their registration
  # period (this means, for which a person can currently register as
  # an attendee)
  #
  # It can take whatever parameters you would send to a
  # Conference#find call.
  def self.in_reg_period(req={})
    self.find(:all, { :conditions => '? BETWEEN ' +
                'COALESCE(reg_open_date, ?) AND ' +
                'COALESCE(reg_close_date, finishes, ?)' %
                [Date.today, Date.today, Date.today],
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
                'cfp_close_date IS NOT NULL) AND ? BETWEEN ' +
                'COALESCE(cfp_open_date, ?) AND ' +
                'COALESCE(cfp_close_date, begins, ?)' %
                [Date.today, Date.today, Date.today],
                :order => :begins}.merge(req))
  end

  # Produce a list of conferences which have not yet begun, for which
  # the person specified as the first parameter is registered, ordered
  # by their beginning date (i.e. the closest first)
  def self.upcoming_for_person(person)
    p_id = person.is_a?(Fixnum) ? person : person.id
    person.conferences.sort_by(&:begins).select(&:upcoming?)
  end

  # Produce a list of conferences which already begun (and might have
  # finished), inversely ordered by their beginning date (i.e. most
  # recent first)
  #
  # It can take whatever parameters you would send to a Person#find
  # call.
  def self.past(req={})
    self.find(:all,
              { :conditions => ['begins <= ?', Time.now],
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
    person.conferences.order_by(&:begins).select(&:past?)
  end

  def publicly_showable_proposals
    self.proposals.select {|p| p.publicly_showable?}
  end

  # How many days is this conference's beginning date from today? The
  # returned value is an integer - positive for upcoming conferences,
  # negative for past conferences.
  def days_to_begins
    ((begins.to_time - Date.today.to_time) / 3600 / 24).to_i
  end

  # How many days are we from this conference's beginning date?
  # Returns a positive integer number (or zero, if the conference
  # starts today), representing the absolute distance.
  def distance_to_begins
    days_to_begins.abs
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
  # yet finished? Is the conference not set to invitation only?
  def accepts_registrations?
    in_reg_period? and !invite_only?
  end

  # Are we in the valid registration period for this conference? (main
  # difference with #accepts_registrations: Users who get invitations
  # are allowed to register if #in_reg_period?, users who try to join
  # by themselves only if #accepts_registrations?)
  def in_reg_period?
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
    return false unless has_cfp?
    Date.today.between?(cfp_open_date || Date.today,
                        last_cfp_date || Date.today)
  end

  # Does this conference have a Call For Papers period? (even if it is
  # not current)
  def has_cfp?
    !(cfp_open_date.nil? and cfp_close_date.nil?)
  end

  # What is the last valid date for the Call For Papers period? This
  # will return cfp_close_date if defined, or the conference beginning
  # date otherwise. If the conference does not accept proposals (see
  # #has_cfp?), returns nil.
  def last_cfp_date
    return nil unless has_cfp?
    cfp_close_date || begins
  end

  # How far is the CfP deadline in the future? (in days)
  # Returns nil if the CfP deadline has already passed
  def cfp_deadline_in
    deadline = last_cfp_date
    return nil if deadline.nil? or Date.today > deadline
    (deadline - Date.today).to_i
  end

  # Is this conference taking place now?
  def current?
    Date.today.between?(begins, finishes)
  end

  # How is this conference categorized? If there are any catalogs defined
  # as extra fields for conferences, the categories are the mapping of each
  # of those that are selected for a given conference.
  #
  # Categories are handed back as a hash where keys are the field name (i.e.
  # conference_type_id) and values are -again- a hash, with :id and :name
  # keys
  def categories
    Hash[self.class.catalogs.map  { |fld, klass|
           name = fld.gsub(/_id$/, '_name');
           [fld, {:id => self.send(fld), :name => self.send(name)}] rescue nil
         }.reject {|cat| cat.nil?}]
  end

  # Do we have propsals submitted by a given user? Give back the list
  def proposals_by_person(person)
    person=Person.find_by_id(person) if person.is_a? Fixnum
    self.proposals.select {|p| p.people.include? person}
  end

  # List of people who are registered for this conference and who have
  # accepted the "ok_conf_mails" boolean
  def people_for_mailing
    self.people.select(&:ok_conf_mails?)
  end

  def has_logo?
    Logo.count(:conditions => ['conference_id = ?', self.id]) > 0
  end

  def logo
    Logo.find(:first, :conditions => ['conference_id = ?', self.id])
  end

  private
  # Ensure the conference has a short name. If none was provided, come
  # up with one - It is basically a readable-URL-helper, so it can be
  # derived from the conference name... Although it's better if a
  # human can properly provide one.
  def ensure_short_name
    # Drop any non-alphanumerics - It is meant to be a _rememberable_
    # and easily inputtable field!
    self.short_name.gsub! /[^a-zA-Z0-9_+\-]/, ''

    # No short name? Duplicated? Just auto-generate a new one
    if short_name.nil? or short_name.blank? or
        ( other = self.class.find_by_short_name(short_name) and
          other.id != self.id )
      # Try to get the first 10 characters of the conference name - And
      # keep adding characters if needed (first from the name, then just
      # '+' signs) if it is not unique.
      #
      # Strip any high characters, as we are cutting the string, and
      # the scissor blade can fall within a wide character, yielding
      # a fugly error
      prepared = name.mb_chars.normalize(:kd).downcase.
        gsub(/\s/, '_').gsub(/[^\w]/,'').gsub(/[^\x00-\x7F]/n,'').to_s
      cutoff = 10
      short = prepared[0..cutoff]
      while self.class.find_by_short_name(short)
        cutoff += 1
        short << (prepared[cutoff] || '+')
      end

      self.short_name = short
    end

    # This is called as a validation... but corrects instead of
    # warning. So, our return value should be:
    true
  end

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

  # If this conference does not handle proposals, CfP dates should be
  # null
  def cfp_data_only_if_manages_proposals
    return true if manages_proposals
    self.cfp_open_date = self.cfp_close_date = nil
    self.public_proposals = false
    true
  end

  # Do not allow the manages_proposals flag to be false if we already
  # have registered proposals
  def no_proposals_unless_manages_proposals
    return true if manages_proposals or proposals.empty?
    errors.add(:manages_proposals,
               _('This conference already has received %d proposals (%s) - ' +
                 'Cannot specify not to handle them.') %
               [self.proposals.size, self.proposals.map {|p| p.id}.join(', ')])
  end

  # Are the two received dates in chronological order? (If either or
  # both are nil, returns true)
  def dates_in_order?(date1, date2)
    return true if date1.nil? or date2.nil? or date2 >= date1
    false
  end

  def ck_in_reg_period(person)
    return true if self.in_reg_period?
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
