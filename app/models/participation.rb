class Participation < ActiveRecord::Base
  belongs_to :person
  belongs_to :conference
  belongs_to :participation_type

  validates_presence_of :person_id
  validates_presence_of :conference_id
  validate :default_type_if_empty
  validate_on_create :ensure_conference_accepts_registrations
  validates_associated :person
  validates_associated :conference
  validates_associated :participation_type
  validates_uniqueness_of(:participation_type_id, 
                          :scope => [ :person_id, :conference_id ])

  before_destroy :dont_unregister_if_has_proposals


  protected
  def default_type_if_empty
    self.participation_type ||= ParticipationType.default
  end

  def ensure_conference_accepts_registrations
    if ! self.conference.accepts_registrations?
      self.errors.add(:conference,
                      _('Registrations for this conference are closed'))
    end  
  end

  def dont_unregister_if_has_proposals
    return true if self.person.authorships.select {|author|
      author.proposal.conference_id==self.conference_id}.empty?
    return false
  end
end
