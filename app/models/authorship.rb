class Authorship < ActiveRecord::Base
  belongs_to :person
  belongs_to :proposal
  acts_as_list :scope => :proposal

  validates_presence_of :person_id
  validates_presence_of :proposal_id
  validates_uniqueness_of :proposal_id, :scope => :person_id
  validates_numericality_of :position
  validates_associated :person, :proposal

  def before_validation_on_create 
    # Make sure every authorship has position (relative ordering) information;
    # 1 if it's the first authorship for a proposal, and at the bottom of the 
    # list otherwise
    return true unless position.blank?
    others = self.proposal.authorships

    if others.blank?
      self.position = 1
    else
      self.position = others.map {|a| a.position}.sort.last + 1
    end
  end
end
