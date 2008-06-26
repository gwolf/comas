class AttendanceAdmController < Admin
  Menu = [[_('Choose a timeslot'), :choose_session],
          [_('Take attendance'), :take]]

  def choose_session
    options = {:per_page => 10,
      :include => [:room, :conference], 
      :page => params[:page]}
    if params[:show_all]
      @tslots = Timeslot.by_time_distance(options)
      @shown = :all
    else
      @tslots = Timeslot.for_day(Date.today, options)
      @shown = :today
    end
  end

  def take
    # Do we have a timeslot we are working on? If not, redirect the
    # user to choose it.
    unless @tslot = Timeslot.find_by_id(params[:id])
      flash[:warning] = _'Please select a timeslot to take attendance for'
      redirect_to :action => 'choose_session'
      return false
    end

    # Results are received by this same controller, the form is shown
    # again ad nauseam
    if params[:person_id]
      person = Person.find_by_id(params[:person_id])
      if person
        register_attendance(person, @tslot) 
      else
        flash[:error] = _('Requested person (%d) does not exist') %
          params[:person_id]
        redirect_to :action => 'take'
        return false
      end
    end

    @last_att = Attendance.find(:all, 
                                :limit => 5,
                                :order => 'created_at DESC',
                                :conditions => ['timeslot_id = ?', @tslot.id])
    @attendance = Attendance.new
  end

  protected
  def register_attendance(person, tslot)
    att = Attendance.new(:person_id => person.id,
                         :timeslot_id => tslot.id)

    # If the person did not register for this conference, add him now
    # (with the default participation type)
    conf = tslot.conference
    if ! person.conferences.include?(conf)
      unless conf.accepts_registrations?
        flash[:error] = _('<em>%s</em> is not registered for <em>%s</em>, ' +
                          'and registrations are closed.') % 
          [person.name, conf.name]
        return false
      end

      flash[:warning] = _('Person <em>%s</em> was not yet registered for ' +
                          'this conference - Registering.') % person.name
      person.conferences << conf
    end

    if att.save
      flash[:notice] = _('Attendance successfully registered')
    else
      flash[:error] = _('Could not register person <em>%s</em> for this ' +
                        'timeslot: %s') % 
        [person.name, att.errors.full_messages.join('<br/>')]
    end
  end
end
