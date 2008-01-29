class AdminTask < ActiveRecord::Base
  include Catalog
  has_and_belongs_to_many :roles
  translates :name
end
