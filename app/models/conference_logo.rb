class ConferenceLogo < ActiveRecord::Base
  belongs_to :conference

  validates_presence_of :conference_id
  validates_related :conference
end
