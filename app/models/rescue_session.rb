class RescueSession < ActiveRecord::Base
  belongs_to :person

  validates_presence_of :link
  validates_presence_of :person_id
  validates_uniqueness_of :person_id

  def self.person_for(link)
    sess = self.find_by_link(link) or return false
    # A link that has been followed should no longer work
    person = sess.person
    sess.destroy
    return person
  end

  def self.create_for(person)
    # Delete any previous rescue sessions for this person
    if sess = self.find_by_person_id(person.id)
      sess.destroy
    end

    sess = self.new(:person => person,
                    :link => Digest::MD5.hexdigest(String.random(16)))
    sess.save!
    return sess
  end
end
