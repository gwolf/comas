class Proposal < ActiveRecord::Base
  has_many :authorships
  has_many :people, :through => :authorships
  belongs_to :prop_type
  belongs_to :prop_status

  validates_presence_of :title
  validates_presence_of :prop_type_id
  validates_presence_of :prop_status_id
  validates_associated :prop_type, :prop_status
end
