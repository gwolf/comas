class AttendanceAdmController < Admin
  Menu = [[_('Choose current session'), :choose_session],
          [_('Take attendance'), :take]]

  def choose_session
    @todays = Timeslot.for_day(Date.today)
    ### What should be done here?
    ###
    ### If the timeslot is not for today, present a list of available
    ### conferences - probably, ordered by their distance from
    ### today(?). The user chooses the conference, and then present
    ### the list of timeslots for it. And only then, redirect to take.
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
    unless person.conferences.include? conf
      person.conferences << conf 
      flash[:warning] = _('Person <em>%s</em> was not yet registered for ' +
                          'this conference - Registering.' % person.name)
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
