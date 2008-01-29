class Person < ActiveRecord::Base
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

  def Person.ck_login(given_login, given_passwd)
    person = Person.find_by_login(given_login)
    return false if person.blank? or
      person.passwd != Digest::MD5.hexdigest(person.pw_salt + given_passwd)

    person.last_login_at = Time.now
    person.save

    person
  end

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
