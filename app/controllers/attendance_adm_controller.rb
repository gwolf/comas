class AttendanceAdmController < Admin
  Menu = [[_('Choose a timeslot'), :choose_session],
          [_('Take attendance'), :take],
          [_('Attendance lists'), :list]]

  before_filter :get_person, :only => [:take, :show_for_person, 
                                       :certificate_for_person]
  before_filter :get_conference, :only => [:list, :show_for_person,
                                           :certificates_by_attendances,
                                           :certificate_for_person]

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

  def take
    # Do we have a timeslot we are working on? Or is there one (and
    # only one) currently active timeslot? If not, redirect the user
    # to choose it.
    unless @tslot = Timeslot.find_by_id(params[:id]) || Timeslot.single_current
      flash[:warning] = _'Please select a timeslot to take attendance for'
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

  def list
    if @conference.nil?
      redirect_to '/'
      flash[:error] = _'Could not find which conference to report'
      return false
    end
    @other_confs = Conference.past
    @timeslots = @conference.timeslots
    @totals = Attendance.totalized_for_conference(@conference)
  end

  def show_for_person
    @attendances = @person.attendances.select {|att|
      att.conference_id == @conference.id
    }
  end

  def certificates_by_attendances
    min = params[:min_attend].to_i
    if min <= 0
      redirect_to :action => 'list', :conference_id => @conference
      return false
    end

    totals = Attendance.totalized_for_conference(@conference)
    people = totals.keys.map {|num| next if num < min; totals[num]}.
      select {|p| p}.flatten

    send_data(certificate_pdf_for(people),
              :filename => 'certificate.pdf', 
              :type => 'application/pdf')
  end

  def certificate_for_person
    send_data(certificate_pdf_for([@person]), 
              :filename => 'certificate.pdf', 
              :type => 'application/pdf')
  end

  protected
  def certificate_pdf_for(people)
    # This method should later on be made configurable - As it is now,
    # it will only print the attendees' names on an arbitrarily
    # decided point of the page, at an arbitrarily decided
    # size. Clearly, that's not good.
    pdf = PDF::Writer.new(:orientation => :landscape, :paper => 'letter')

    people.sort_by {|p| p.famname.downcase}.each do |person|
      pdf.stroke_color(Color::RGB.new(0,0,0))
      pdf.move_pointer(200.0)
      ### PDF::Writer does not currently (as of version 1.1.7) support
      ### UTF8... Sorry, we will lose on some charsets :-/ At least,
      ### Iconv is in the standard Ruby library
      pdf.text(Iconv.conv('ISO-8859-15', 'UTF-8', person.name),
               :justification => :center, :font_size => 20)
      pdf.start_new_page
    end

    return pdf.render
  end

  def register_attendance(person, tslot)
    att = Attendance.new(:person_id => person.id,
                         :timeslot_id => tslot.id)

    # If the person did not register for this conference, add him now
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

  # Get either the conference specified in the parameters, or the
  # latest one which started already
  def get_conference
    @conference = Conference.find_by_id(params[:conference_id]) || 
      Conference.past[0]
    return false unless @conference
  end

  def get_person
    @person = Person.find_by_id(params[:person_id])
  end
end
