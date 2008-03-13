class Person < ActiveRecord::Base
  acts_as_magic_model
  belongs_to :person_type
  has_many :authorships
  has_many :proposals, :through => :authorships
  has_and_belongs_to_many :roles
  has_and_belongs_to_many :conferences

  validates_presence_of :firstname
  validates_presence_of :famname
  validates_presence_of :login
  validates_presence_of :passwd
  validates_presence_of :person_type_id
  validates_uniqueness_of :login
  validates_associated :person_type

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
       person_type_id pw_salt)
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

  private
  def pw_salt
    self[:pw_salt]
  end
end
