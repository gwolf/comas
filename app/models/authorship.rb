class Authorship < ActiveRecord::Base
  belongs_to :person
  belongs_to :proposal
  acts_as_list :scope => :proposal

  validates_presence_of :person_id
  validates_presence_of :proposal_id
  validates_uniqueness_of :proposal_id, :scope => :person_id
  validates_numericality_of :position
  validates_associated :person, :proposal

  before_validation_on_create :set_position_if_empty
  before_create :ensure_person_is_registered_for_conf
  after_destroy :remove_orphaned_proposals

  protected
  # Make sure every authorship has position (relative ordering)
  # information; 1 if it's the first authorship for a proposal, and at
  # the bottom of the list otherwise
  def set_position_if_empty
    return true unless position.blank?
    others = self.proposal.authorships

    if others.blank?
      self.position = 1
    else
      self.position = others.map(&:position).sort.last + 1
    end
  end

  # If the person registering this proposal is not registered for the
  # relevant conference, register him
  def ensure_person_is_registered_for_conf
    self.person.conferences << self.proposal.conference unless
      self.person.conferences.include?(self.proposal.conference)
  end

  # If the last remaining author de-registers himself from a proposal,
  # remove the proposal (and avoid having it as an orphan)
  def remove_orphaned_proposals
    return true if ! self.proposal.people.empty?
    self.proposal.destroy
  end
end
