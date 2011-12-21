class Attendance < ActiveRecord::Base
  belongs_to :timeslot
  belongs_to :person

  validates_presence_of :timeslot_id
  validates_presence_of :person_id
  validates_associated :timeslot
  validate :person_registered_in_conference
  validates_associated :person
  validates_uniqueness_of(:person_id, :scope => :timeslot_id,
                          :message => _('Requested person already ' +
                                        'registered for this timeslot'))


  # We _could_ add a validation for a person not to be registered for
  # a timeslot belonging to a conference he is not part of - But
  # registering for the right conference should not be imposed to a
  # user waiting on a long queue! We provide only a
  # people_not_in_conference finder method to find the list of probable
  # users which have to be registered.
  #
  # Watch out: This is bound to be a VERY heavy query!
#   def self.people_not_in_conference(conf)
#     self.find(:all, :include => :person
#               :conditions => ['timeslot_id not in (?)', conf.timeslot_ids]
#               ).map {|a|
#       a.person}.uniq.reject {|p|
#       p.conferences.include? conf}
#   end

  # All of the attendances for a given person
  def self.for_person(person)
    person = Person.find_by_id(person) if person.is_a? Fixnum
    self.find(:all, :conditions => ['person_id = ?', person.id])
  end

  # All of the attendances registered for a given conference
  #
  # Very often, calling this method will be immediately followed by
  # finding each of its results' associated people - Make it easy on
  # the database by including the people on the query itself.
  def self.for_conference(conf)
    conf = Conference.find_by_id(conf) if conf.is_a? Fixnum
    self.find(:all, :conditions => ['timeslot_id in (?)', conf.timeslot_ids],
              :include => :person)
  end

  # Gives the full list of people who attended the specified
  # conference. The results are given back as a hash, where the keys
  # are the number of attendances each given person had.
  def self.totalized_for_conference(conf)
    totals = {}
    people = {}

    self.for_conference(conf).each do |att|
      people[att.person] ||= 0
      people[att.person] += 1
    end

    people.keys.each do |att|
      totals[people[att]] ||= []
      totals[people[att]] << att
    end

    totals
  end

  # The conference to which this attendance belongs
  def conference_id; self.timeslot.conference_id; end
  def conference; Conference.find_by_id(self.conference_id); end

  protected
  def person_registered_in_conference
    conf = timeslot.conference

    return true if conf.people.include? person
    begin
      conf.people << person
    rescue ActiveRecord::RecordNotSaved => err
      errors.add_to_base(err.message)
      return false
    end
  end
end
