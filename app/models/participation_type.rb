class ParticipationType < ActiveRecord::Base
  acts_as_catalog
  has_many :participations

  def self.default
    self.find(:first, :order => 'id')
  end
end
