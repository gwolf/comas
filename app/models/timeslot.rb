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

  # Returns a paginated list with all of the timeslots for the
  # specified date, ordered by start time
  def self.for_day(date, req={})
    self.paginate(:all, 
                  {:conditions => ['start_time BETWEEN ? and ?',
                                  date.beginning_of_day, date.end_of_day],
                    :order => :start_time,
                    :page => 1}.merge(req))
  end

  # Produce a paginated list of timeslots, ordered by the absolute
  # distance between their start_time and the current time. 
  #
  # It can take whatever parameters you would send to a
  # WillPaginate#paginate call. Of course, you can specify a different
  # ordering - in which case this would act as a normal paginator 
  def self.by_time_distance(req={})
    self.paginate(:all, 
                  { :order => 'CASE WHEN start_time > now() THEN start_time ' +
                    ' - now() ELSE now() - start_time END',
                    :page => 1}.merge(req))
  end

  # An easier-on-the-eyes format...
  def short_start_time
    start_time.strftime('%d-%m-%Y %H:%M')
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
