# -*- coding: utf-8 -*-
class Person < ActiveRecord::Base
  acts_as_magic_model
  has_one :photo, :dependent => :destroy
  has_one :rescue_session, :dependent => :destroy
  has_many :authorships, :dependent => :destroy
  has_many :proposals, :through => :authorships
  has_many(:sent_invites, :foreign_key => 'sender_id',
           :class_name => 'ConfInvite')
  has_many(:claimed_invites, :foreign_key => 'claimer_id',
           :class_name => 'ConfInvite')
  has_and_belongs_to_many :admin_tasks
  has_and_belongs_to_many(:conferences, :order => :begins,
                          :before_add => :ck_accepts_registrations,
                          :before_remove => :dont_unregister_if_has_proposals)
  has_many :attendances

  validates_presence_of :firstname
  validates_presence_of :famname
  validates_presence_of :login
  validates_presence_of :passwd
  validates_presence_of :email
  validates_uniqueness_of :login
  validates_format_of(:email,
                      :with => RFC822::EmailAddress,
                      :message => _('A valid e-mail address is required'))
  before_validation :trim_base_attr

  def self.ck_login(given_login, given_passwd)
    person = Person.find_by_login(given_login)
    return false if person.blank? or
      person.passwd != Digest::MD5.hexdigest(person.pw_salt + given_passwd)

    person.last_login_at = Time.now
    person.save

    person
  end

  def self.core_attributes
    %w(created_at email famname firstname id last_login_at login passwd
       pw_salt ok_conf_mails ok_general_mails).map do |attr|
      self.columns.select{|col| col.name == attr}[0]
    end
  end
  def core_attributes; self.class.core_attributes; end

  # Returns a list of any user-listable attributes that are not part of the
  # base Person data
  def self.extra_listable_attributes
    self.columns - self.core_attributes
  end
  def extra_listable_attributes; self.class.extra_listable_attributes; end

  # Returns a flattened list of attributes, good to be used in a
  # generic listing. This means, the attributes are by themselves both
  # good enough as a column header and valid methods that can be sent
  # to the person instance.
  def self.flattributes_for_list
    self.columns.map do |col|
      name = col.name
      if name =~ /^(.*)_id$/
        attr_for_name = "#{$1}_name"
        name = attr_for_name if self.instance_methods.include? attr_for_name
      end
      name
    end
  end

  # List of users which accepted to receive general information mails
  def self.mailable
    self.find(:all, :conditions => 'ok_general_mails')
  end

  # Performs a (optionally paginated) search for the specified string
  # in any of the firstname, famname or login fields.
  #
  # If no parameters are specified, it just returns a full listing,
  # ordered by ID. Any additional parameters for the search can be
  # specified in the second parameter (as a hash).
  #
  # The resulting list will be paginated if the :paginate attribute is
  # true.
  def self.search(name=nil, conf=nil, params={})
    paginated = params.delete :paginate
    params.merge!(:conditions=>['firstname ~* ? or famname ~* ? or login ~* ?',
                                name, name, name]) unless name.nil?
    params[:order] = 'id' if params[:order].nil?
    if paginated
      params[:page] = 1 if params[:page].nil?
      self.paginate(params)
    else
      self.find(:all, params)
    end
  end

  def self.name_find(name=nil, params = {})
    params[:conditions] = ['firstname ~* ? or famname ~* ? or login ~* ?',
                           name, name, name] if name
    self.find(:all, params)
  end

  # Sets the encrypted password - Regenerates the random salt and
  # computes a MD5 for the supplied plaintext password.
  def passwd= plain
    # Don't accept empty passwords!
    return nil if plain.blank? or /^\s*$/.match(plain)
    self.pw_salt = String.random(8)
    self['passwd'] = Digest::MD5.hexdigest(pw_salt + plain)
  end

  def name
    "#{firstname} #{famname}"
  end

  def name_and_email
    "#{name} <#{email}>"
  end

  # Did this person attend the specified conference?
  def attended?(conf)
    !attendances.select {|a| a.conference_id==conf.id}.empty?
  end

  # Avoid moving the full query of a photo if we just want to check
  # for the photo's existence
  def has_photo?
    ! Photo.find_by_person_id(self.id, :select=>'id').nil?
  end

  def photo
    Photo.find(:first, :conditions => ['person_id = ?', self.id])
  end

  def has_proposal_for?(conf)
    # Accept either a conference object or a conference ID
    conf = Conference.find_by_id(conf) if conf.is_a? Integer
    self.proposals.map(&:conference).include?(conf)
  end

  def has_admin_task?(task)
    # Accept either an admin_task object, its ID or its description
    task = AdminTask.find_by_id(task) if task.is_a? Fixnum
    task = AdminTask.find_by_sys_name(task.to_s) if (task.is_a? String or
                                                     task.is_a? Symbol)

    self.admin_tasks.include? task
  end

  def upcoming_conferences
    self.conferences.select(&:upcoming?).sort_by(&:begins)
  end

  def conferences_for_submitting
    self.upcoming_conferences.select(&:accepts_proposals?)
  end

  # Which conferences can this person invite a friend to? (see
  # PeopleController#invite)
  def conferences_for_invite
    # Conference administrators can invite people to any future
    # conference
    return Conference.upcoming if has_admin_task? :conferences_adm
    # And regular users can invite people to any conference they are
    # signed up for (except for those marked invite-only — Those are
    # only for administrators!)
    self.conferences.reject {|c| c.invite_only?}
  end

  def register_for(conf)
    conf = Conference.find(conf) if conf.is_a?(Fixnum)
    # Already registered? Don't panic! Act naturally!
    return true if self.conferences.include?(conf)
    if conf.accepts_registrations?
      self.conferences << conf
      return true
    end

    #### Check this over:
    #### It does not work as it is (i.e. it fails but does not send the
    #### error message)
    self.errors.add(:conferences,
                    _('Registrations for this conference are closed'))
    false
  end

  # Is this user signed up for any conferences which accept proposals
  # now?
  def can_submit_proposals_now?
    ! conferences_for_submitting.empty?
  end

  # It is common for people to forget they have already registered at
  # the site. The controllers can call this method to check whether a
  # person is a probable duplicate:
  #
  # - Is somebody already registered with this same mail address?
  # - Is somebody already registered with this full name? (somewhat
  #   fuzzily - Case insensitive, spaces stripped
  #
  # Returns false if no probable duplicates are found, or a list of
  # candidates if they are.
  def probable_duplicate?
    res = Person.find :all, :conditions =>
      ['id != ? AND (email = ? OR (trim(upper(firstname)) = trim(upper(?)) AND ' +
       'trim(upper(famname)) = trim(upper(?))))', id||0, email||'', firstname||'', famname||'']
    res.size > 0 && res
  end

  def last_login_date
    begin
      last_login_at.to_date
    rescue NoMethodError
    end
  end

  def created_date
    begin
      created_at.to_date
    rescue NoMethodError
    end
  end

  protected
  def pw_salt
    self[:pw_salt]
  end

  def ck_accepts_registrations(conf)
    return true if conf.in_reg_period?
    raise(ActiveRecord::RecordNotSaved,
          _('Conference %s does not currently accept registrations') %
          conf.name)
  end

  def dont_unregister_if_has_proposals(conf)
    return true unless self.has_proposal_for? conf
    raise(ActiveRecord::RecordNotSaved,
          _('Cannot leave %s - This user still has proposals '+
            'on this conference') % conf.name)
  end

  # Removes whitespace before and after the "real" values on
  # firstname, famname, login and email (the fields where such
  # mistakes are most frequently seen and should always be corrected)
  def trim_base_attr
    %w(firstname famname email login).each do |attr|
      val = self.send(attr) || ''
      self.send("#{attr}=", val.gsub(/^\s*/,'').gsub(/\s*$/,''))
    end
  end
end
