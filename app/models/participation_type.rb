class ParticipationType < ActiveRecord::Base
  acts_as_catalog
  has_many :participations

  def self.default
    self.find(:first, :order_by => 'id')
  end
end
