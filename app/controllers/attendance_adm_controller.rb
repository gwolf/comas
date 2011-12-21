# -*- coding: utf-8 -*-
class AttendanceAdmController < Admin
  helper :certificates_adm
  Menu = [[_('Choose a timeslot'), :choose_session],
          [_('Take attendance'), :take],
          [_('Attendance lists'), :list]
         ]

  before_filter :get_person, :only => [:take, :for_person]
  before_filter :get_conference, :only => [:list, :for_person,
                                           :certificates_by_attendances,
                                           :certificate_for_person,
                                           :att_by_tslot,
                                           :xls_list,
                                           :list_graphic
                                          ]

  # Prompts the user which session to use for taking attendance. By
  # default, shows only active sessions (those for which we are in the
  # tolerance period); all sessions will be shown if params[:show_all]
  # is true.
  def choose_session
    options = {:per_page => 10,
      :include => [:room, :conference],
      :page => params[:page]}
    if params[:show_all]
      @tslots = Timeslot.by_time_distance(options)
      @shown = :all
    else
      @tslots = Timeslot.current
      @shown = :current
    end
  end

  # Registers the attendance for a given person / timeslot
  def take
    # Do we have a timeslot we are working on? Or is there one (and
    # only one) currently active timeslot? If not, redirect the user
    # to choose it.
    unless @tslot = Timeslot.find_by_id(params[:id]) || Timeslot.single_current
      flash[:warning] << _('Please select a timeslot to take attendance for')
      redirect_to :action => 'choose_session'
      return false
    end

    # Results are received by this same controller, the form is shown
    # again ad nauseam
    if @person
      register_attendance(@person, @tslot)
    end

    @last_att = Attendance.find(:all,
                                :limit => 5,
                                :order => 'created_at DESC',
                                :conditions => ['timeslot_id = ?', @tslot.id])
    @attendance = Attendance.new
  end

  # Presents the number of attendances per timeslot for a given
  # conference, and allows for listing all other past conferences
  # which have timeslots registered
  def list
    @other_confs = Conference.past_with_timeslots
    @totals = Attendance.totalized_for_conference(@conference) if @conference
  end

  def list_graphic
    g = Gruff::AccumulatorBar.new('480x300')
    g.title = _('Number of attendances')
    g.sort = false
    g.hide_legend = true

    totals = Attendance.totalized_for_conference(@conference)

    # For easier handling, mangle totals from a hash to a
    # descending-ordered array
    attendances = []
    totals.keys.sort.reverse.each do |att|
      value = totals[att].size
      label = '%d: %d' % [att, value]
      g.labels[g.labels.size] = label
      attendances << value
    end
    g.data _('Attendances'), attendances

    send_data(g.to_blob('png'), :type => 'image/png', :disposition => 'inline')
  end

  # Generate a XLS listing with all the attendances for a given conference
  def xls_list
    xls = SimpleXLS.new
    columns = [_('Timeslot'), _('Room'), _('Name'), _('Attendance time')]

    xls.add_header [_('Attendances listing for %s') % @conference.name]
    xls.add_header columns

    atts = {}
    ts = @conference.timeslots.sort_by {|ts| ts.start_time}
    ts.each { |t| atts[t.id] = t.attendances.sort_by {|a| a.person.name } }

    ts.map do |ts|
      atts[ts.id].map do |att|
        xls.add_row(ts.start_time.to_s(:listing), ts.room.name,
                    att.person.name, att.created_at.to_s(:time_only))
      end
    end

    send_data(xls.to_s, :type => 'application/vnd.ms-excel',
              :filename => '%s_list.xls' % @conference.short_name)
  end

  # Produces the attendance detail for a given timeslot
  def att_by_tslot
    begin
      @tslot = Timeslot.find_by_id(params[:timeslot_id])
      raise ActiveRecord::RecordInvalid unless
        @conference.timeslots.include? @tslot
    rescue
      flash[:error] << _('Invalid timeslot requested')
      redirect_to :action => 'list', :conference_id => @conference
      return false
    end

    @attendances = Attendance.paginate(:all, :page => params[:page],
                                       :conditions => ['timeslot_id = ?',
                                                      @tslot.id],
                                       :order => 'created_at')
  end

  # Gives the attendances detail for the specified person on the
  # specified conference
  def for_person
    @attendances = @person.attendances.select {|att|
      att.conference_id == @conference.id
    }
    @formats = CertifFormat.find(:all, :order => :id)
  end

  # Produces the list of certificates to be generated for the
  # specified conference according to the minimum required attendance
  # levels
  def certificates_by_attendances
    min = params[:min_attend].to_i
    if min <= 0
      redirect_to :action => 'list', :conference_id => @conference
      return false
    end

    totals = Attendance.totalized_for_conference(@conference)
    people = totals.keys.map {|num| next if num < min; totals[num]}.
      select {|p| p}.flatten.sort_by(&:famname)

    ### /!\ I am hard-wiring the first CertifFormat here. Not nice!
    ###     :-/ Provide a way to choose one... soon :-}
    send_data(CertifFormat.find(:first).generate_pdf_for(people, @conference),
              :filename => 'certificate.pdf',
              :type => 'application/pdf')
  end

  protected
  def register_attendance(person, tslot)
    if previous = person.attendances.find(:first, :conditions =>
                                          ['timeslot_id = ?', tslot.id])
      flash[:notice] << _('This person has already been registered for this ' +
                          'timeslot. No action taken.')
      return false
    end
    att = Attendance.new(:person_id => person.id,
                         :timeslot_id => tslot.id)

    # If the person did not register for this conference, add him now
    conf = tslot.conference
    if ! person.conferences.include?(conf)
      unless conf.accepts_registrations?
        flash[:error] << _('<em>%s</em> is not registered for <em>%s</em>, ' +
                           'and registrations are closed.') %
          [person.name, conf.name]
        return false
      end

      flash[:warning] << _('Person <em>%s</em> was not yet registered for ' +
                          'this conference - Registering.') % person.name
      person.conferences << conf
    end

    if att.save
      flash[:notice] << _('Attendance successfully registered')
    else
      flash[:error] << _('Could not register person <em>%s</em> for this ' +
                         'timeslot: %s') %
        [person.name, att.errors.full_messages.join('<br/>')]
    end
  end

  # Get either the conference specified in the parameters, or the
  # latest one with registered timeslots which started already
  def get_conference
    @conference = Conference.find_by_id(params[:conference_id]) ||
      Conference.past_with_timeslots[0]
    return false unless @conference
  end

  def get_person
    pers_id = params[:person_id]
    return true if pers_id.nil? or pers_id.blank?
    @person = Person.find_by_id(pers_id) rescue nil
    flash[:error] << _('Invalid person specified: %s') %
      h(pers_id) if @person.nil?
  end
end
