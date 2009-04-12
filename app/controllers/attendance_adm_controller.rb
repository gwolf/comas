class AttendanceAdmController < Admin
  class NotForUs < Exception; end
  Menu = [[_('Choose a timeslot'), :choose_session],
          [_('Take attendance'), :take],
          [_('Attendance lists'), :list],
          [_('Certificate formats'), :certif_formats_list]]

  before_filter :get_person, :only => [:take, :for_person, 
                                       :certificate_for_person]
  before_filter :get_conference, :only => [:list, :for_person,
                                           :certificates_by_attendances,
                                           :certificate_for_person,
                                           :att_by_tslot,
                                           :gen_sample_certif ]
  before_filter :get_format, :only => [:certif_format,
                                       :add_certif_format_line,
                                       :delete_certif_format_line,
                                       :gen_sample_certif]

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

  def list
    if @conference.nil?
      redirect_to '/'
      flash[:error] << _('Could not find which conference to report')
      return false
    end
    @other_confs = Conference.past_with_timeslots
    @totals = Attendance.totalized_for_conference(@conference)
  end

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

    @attendances = @tslot.attendances.sort_by {|a| a.created_at}
  end

  def for_person
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

    send_data(certificate_pdf_for(people, CertifFormat.find(1)),
              :filename => 'certificate.pdf', 
              :type => 'application/pdf')
  end

  def certificate_for_person
    send_data(certificate_pdf_for([@person], CertifFormat.find(1)), 
              :filename => 'certificate.pdf', 
              :type => 'application/pdf')
  end

  def certif_formats_list
    @formats = CertifFormat.paginate(:all, :order => :id, 
                                     :include => :certif_format_lines,
                                     :page => params[:page])
  end

  def certif_format
    @new_line = CertifFormatLine.new
    @conferences = Conference.find(:all)
    if request.post?
      @format.update_attributes(params[:certif_format])
    end
  end

  def new_certif_format
    @format = CertifFormat.new
  end

  def add_certif_format_line
    begin
      raise NotForUs unless request.post?
      line = CertifFormatLine.new(params[:certif_format_line])
      line.certif_format = @format
      line.save!
    rescue NotForUs, ActiveRecord::RecordNotFound, NoMethodError => err
    end

    redirect_to :action => 'certif_format', :id => @format
  end

  def delete_certif_format_line
    begin
      raise NotForUs unless request.post?
      line = CertifFormatLine.find(params[:line_id])
      raise NotForUs unless line.certif_format = @format
      line.destroy
    rescue NotForUs, ActiveRecord::RecordNotFound, NoMethodError
    end

    redirect_to :action => 'certif_format', :format_id => @format
  end

  def gen_sample_certif
    send_data(certificate_pdf_for([@user], CertifFormat.find(1)),
              :filename => 'test_certificate.pdf',
              :type => 'application/pdf')
  end

  protected
  def certificate_pdf_for(people, fmt)
    pdf = PDF::Writer.new(:orientation => fmt.orientation,
                          :paper => fmt.paper_size)
    pdf.stroke_color(Color::RGB.new(0,0,0)) # Just paint it all black
    
    people.each do |person|
      fmt.certif_format_lines.each do |line|
        ### PDF::Writer does not currently (as of version 1.1.7) support
        ### UTF8... Sorry, we will lose on some charsets :-/ At least,
        ### Iconv is in the standard Ruby library
        pdf.add_text_wrap(line.x_pos, line.y_pos, line.max_width,
                          Iconv.conv('ISO-8859-15', 'UTF-8',
                                     line.text_for(person, @conference)), 
                          line.font_size, line.justification.to_sym)
      end
      pdf.start_new_page unless person == people.last
    end

    return pdf.render
  end

  def register_attendance(person, tslot)
    if previous = Person.find(1).
        attendances.find(:first, :conditions =>['timeslot_id = ?', tslot.id])
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
    @person = Person.find_by_id(pers_id)
    flash[:error] << _('Invalid person specified') if @person.nil?
  end

  def get_format
    @format = CertifFormat.find_by_id(params[:format_id], 
                                      :include => :certif_format_lines)
    return true if @format
    flash[:error] << _('Invalid format specified')
    false
  end  
end
