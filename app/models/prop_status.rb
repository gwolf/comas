class PropStatus < ActiveRecord::Base
  acts_as_catalog
  has_many :proposals
end
