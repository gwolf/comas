class Person < ActiveRecord::Base
  acts_as_magic_model
  has_one :rescue_session, :dependent => :destroy
  has_many :authorships, :dependent => :destroy
  has_many :proposals, :through => :authorships
  has_and_belongs_to_many :admin_tasks
  has_many :participations, :dependent => :destroy
  has_many :conferences, :through => :participations, :order => :begins
  has_many :participation_types, :through => :participations

  validates_presence_of :firstname
  validates_presence_of :famname
  validates_presence_of :login
  validates_presence_of :passwd
  validates_uniqueness_of :login

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
       pw_salt)
  end
  def core_attributes; self.class.core_attributes; end

  # Returns a list of any user-listable attributes that are not part of the
  # base Person data
  def self.extra_listable_attributes 
    self.column_names - self.core_attributes
  end
  def extra_listable_attributes; self.class.extra_listable_attributes; end

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

  # Just remember that 'participation' sometimes sounds nebulous... A
  # participation might be as a speaker, as an organizer, as an
  # atendee.. As any ParticipationType.
  def participation_in(conf)
    # Accept either a conference object or a conference ID
    conf = Conference.find_by_id(conf) if conf.is_a? Integer
    self.participations.select {|part| part.conference == conf}.first
  end

  def has_proposal_for?(conf)
    # Accept either a conference object or a conference ID
    conf = Conference.find_by_id(conf) if conf.is_a? Integer
    self.proposals.map {|p| p.conference}.include?(conf)
  end

  def has_admin_task?(task)
    # Accept either an admin_task object, its ID or its description
    task = AdminTask.find_by_id(task) if task.is_a? Fixnum
    task = AdminTask.find_by_sys_name(task.to_s) if (task.is_a? String or
                                                     task.is_a? Symbol)

    self.admin_tasks.include? task
  end

  def upcoming_conferences
    Conference.upcoming_for_person(self)
  end

  def conferences_for_submitting
    self.upcoming_conferences.select {|conf| conf.accepts_proposals?}
  end

  # Is this user signed up for any conferences which accept proposals
  # now?
  def can_submit_proposals_now?
    ! conferences_for_submitting.empty?
  end

  private
  def pw_salt
    self[:pw_salt]
  end
end
