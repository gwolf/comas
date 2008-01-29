class PropType < ActiveRecord::Base
  include Catalog
  has_many :proposals
  translates :name
end
