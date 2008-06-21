class Timeslot < ActiveRecord::Base
  belongs_to :room
  belongs_to :conference
  has_many :proposals
  has_many :attendances
  has_and_belongs_to_many :prop_types

  validates_presence_of :start_time
  validates_presence_of :room_id
  validates_presence_of :conference_id
  validates_associated :room, :conference
  validate :during_conference_days

  # Returns all of the timeslots for the specified date, ordered by
  # start time
  def self.for_day(date)
    self.find(:all, 
              :conditions => ['start_time BETWEEN ? and ?',
                              date.beginning_of_day, date.end_of_day],
              :order => :start_time)
  end

  protected
  def during_conference_days
    conf = self.conference
    return true if start_time.to_date.between?(conf.begins,
                                               conf.finishes)
    errors.add(:start_time, _('Must start within the conference dates ' +
                              '(%s - %s)') % [conf.begins, conf.finishes])
  end
end
