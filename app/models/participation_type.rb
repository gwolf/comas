class ParticipationType < ActiveRecord::Base
  has_many :participations

  validates_presence_of :name
  validates_uniqueness_of :name

  def self.default
    self.find(:first)
  end
end
