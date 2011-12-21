class Timeslot < ActiveRecord::Base
  belongs_to :room
  belongs_to :conference
  has_one :proposal
  has_many :attendances, :dependent => :destroy
  has_and_belongs_to_many :prop_types

  validates_presence_of :start_time
  validates_presence_of :room_id
  validates_presence_of :conference_id
  validates_associated :room, :conference
  validate :during_conference_days
  validate :tolerances_correctly_formatted
  validate :no_overlapping_timeslots

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
    # It is much more efficient to do the date comparisons inside the
    # DB, but the way to do so it is completely RDBMS-specific. So,
    # attempt to do it efficiently, but fall back if needed.
    case Timeslot.connection.adapter_name.downcase
    when 'postgresql'
      self.paginate(:all,
                    { :order => 'abs(extract(epoch from start_time - now()))',
                      :page => 1}.merge(req))
    else
      self.find(:all).merge(req).
        sort_by {|t| (t.start_time - Time.now).abs}.paginate(:page => 1)
    end
  end

  # Returns the paginated list of current timeslots - those for which
  # attendance can be taken now.
  #
  # It can take whatever parameters you would send to a
  # WillPaginate#paginate call. Of course, you can specify a different
  # search criteria - in which case this would act as a normal
  # paginator
  def self.current(req={})
    self.concurrent_with(Time.now, req)
  end

  # Returns the paginated list of timeslots concurrent with the Time
  # object passed as the first parameter - This means, those timeslots
  # for which the current system clock is between tolerance_pre and
  # tolerance_post. If either of them is not defined, we take the
  # default values (see default_tolerance_pre, default_tolerance_post)
  #
  # It can take whatever parameters you would send to a
  # WillPaginate#paginate call. Of course, you can specify a different
  # search criteria - in which case this would act as a normal
  # paginator
  def self.concurrent_with(moment, req={})
    self.paginate(:all, {:conditions =>
                    [%Q(? BETWEEN start_time -
                        coalesce(tolerance_pre, ?)::interval AND
                        start_time +
                        coalesce(tolerance_post, ?)::interval ),
                     moment,
                     self.default_tolerance_pre,
                     self.default_tolerance_post],
                    :page => 1}.merge(req))
  end

  # There are many operations which want to get the current timeslot,
  # in case there is only one - So, if there is only a single current
  # timeslot, return it. If there is none (or there are more), return
  # nil.
  def self.single_current
    curr = self.current
    return nil unless curr.size == 1
    return curr[0]
  end

  # An easier-on-the-eyes format...
  def short_start_time
    start_time.strftime('%d-%m-%Y %H:%M')
  end

  # The time difference between now and the timeslot's start_time,
  # returned as the number of seconds for its beginning (i.e. Ruby's
  # natural interval representation).
  #
  # The result will be negative for timeslots which have already
  # begun.
  def seconds_to_start
    Time.now - start_time
  end

  # The time difference between now and the timeslot's start_time,
  # returned as a d+hh:mm:ss string ('d+' is the number of days - I
  # could not find a more natural notation).
  def time_to_start
    total = seconds_to_start
    direction = total < 0 ? '-' : ''
    total = total.abs

    days = (total / 86400).to_i
    days = '' if days == 0 # Ugly, but more readable in the end :-/
    hours = (total % 86400) / 3600
    minutes = (total % 3600) / 60
    seconds = total % 60

    '%s%s %02d:%02d:%02d' % [direction, days, hours, minutes, seconds]
  end

  # The systemwide default value for pre-timeslot tolerance: Whatever
  # is defined in SysConf for tolerance_pre, or 30 minutes if not
  # defined.
  def self.default_tolerance_pre
    SysConf.value_for('tolerance_pre') || '00:30:00'
  end

  # The systemwide default value for post-timeslot tolerance: Whatever
  # is defined in SysConf for tolerance_post, or 30 minutes if not
  # defined.
  def self.default_tolerance_post
    SysConf.value_for('tolerance_post') || '00:30:00'
  end

  # Intervals in Ruby are represented as a semi-opaque "thing" that
  # becomes an integer number of seconds when needed... Treating them
  # in any other way breaks applications. So, as soon as we get them,
  # stringify them to something PostgreSQL will grok.
  def tolerance_pre=(time)
    if time.nil? or time.blank? or time==0
      self[:tolerance_pre] = nil
    else
      self[:tolerance_pre] = interval_to_seconds(time)
    end
  end

  # Intervals in Ruby are represented as a semi-opaque "thing" that
  # becomes an integer number of seconds when needed... Treating them
  # in any other way breaks applications. So, as soon as we get them,
  # stringify them to something PostgreSQL will grok.
  def tolerance_post=(time)
    if time.nil? or time.blank? or time==0
      self[:tolerance_post] = nil
    else
      self[:tolerance_post] = interval_to_seconds(time)
    end
  end

  def effective_tolerance_pre
    tolerance_pre || self.class.default_tolerance_pre
  end

  def effective_tolerance_post
    tolerance_post || self.class.default_tolerance_post
  end

  protected
  def interval_to_seconds(time)
    # A nil is a nil is a nil. And if the interval includes a ':',
    # Postgres will grok it better than me.
    return time if time.nil? or time=~/:/
    seconds = time.to_i
    if seconds >= 2**31 or seconds <= -2**31
      raise TypeError, "#{time} interval out of range"
    end
    "#{seconds} seconds"
  end

  def during_conference_days
    conf = self.conference
    return true if start_time.to_date.between?(conf.begins,
                                               conf.finishes)
    errors.add(:start_time, _('Must start within the conference dates ' +
                              '(%s - %s)') % [conf.begins, conf.finishes])
  end

  # The tolerance periods are just strings. However, they must make
  # sense - So, we limit them to be hh:mm:ss.
  #
  # Nil/blank is acceptable (i.e. it means "default value is OK")
  def tolerances_correctly_formatted
    [:tolerance_pre, :tolerance_post].each do |attr|
      field = self.send(attr)
      field.nil? or field.blank? or field =~ /^\d\d?:\d\d(:\d\d)?$/ or
        errors.add(field, _('Wrong format (should be hh:mm or hh:mm:ss)'))
    end
  end

  # Two timeslots are overlapping if they happen at the same room, and
  # their tolerance periods overlap.
  #
  # Evaluate for the future: Will we implement proposal types per
  # timeslot? If so, we could manage timeslot duration and have a more
  # complete and real timeslot overlapping checks... Meanwhile, here
  # we go
  def no_overlapping_timeslots
    # Ugly, ugly, SQL query follows... Still, it's the clearest way I
    # could find to check for overlapping timeslots
    sql_cond = "room_id = ? AND
        (start_time-COALESCE(tolerance_pre, ?)::interval BETWEEN
             ?::timestamp - ?::interval AND ?::timestamp + ?::interval OR
         start_time+COALESCE(tolerance_post, ?)::interval BETWEEN
             ?::timestamp - ?::interval AND ?::timestamp + ?::interval)"

    pre = effective_tolerance_pre
    d_pre = self.class.default_tolerance_pre
    post = effective_tolerance_post
    d_post = self.class.default_tolerance_pre

    others = self.class.find(:all,
        :conditions => [sql_cond, room_id,
                        d_pre, start_time, pre, start_time, post,
                        d_post, start_time, pre, start_time, post]
                             ).select {|ts| ts.id != self.id}
    return true if others.empty?

    errors.add(:start_time, _('Timeslot is overlapping on room %s with %s') %
               [self.room.name, others.map {|ts| ts.id}.join(', ')])
  end
end
