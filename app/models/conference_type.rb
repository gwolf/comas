class ConferenceType < ActiveRecord::Base
  acts_as_catalog
  has_many :conferences
end
