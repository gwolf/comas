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
                                       :delete_certif_format,
                                       :add_certif_format_line,
                                       :delete_certif_format_line,
                                       :gen_sample_certif,
                                       :certificate_for_person]

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

    @attendances = @tslot.attendances.sort_by(&:created_at)
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

    ### /!\ I am hard-wiring the first CertifFormat here. Not nice! :-/
    send_data(certificate_pdf_for(people, CertifFormat.find(:first)),
              :filename => 'certificate.pdf', 
              :type => 'application/pdf')
  end

  # Generates a certificate for the specified person / conference /
  # format
  def certificate_for_person
    send_data(certificate_pdf_for([@person], @format),
              :filename => 'certificate.pdf', 
              :type => 'application/pdf')
  end

  # Lists the registered certificate formats
  def certif_formats_list
    @formats = CertifFormat.paginate(:all, :order => :id, 
                                     :include => :certif_format_lines,
                                     :page => params[:page])
    @new_fmt = CertifFormat.new
  end

  def certif_format
    @new_line = CertifFormatLine.new
    @conferences = Conference.find(:all)
    @units = CertifFormat.full_units
    if request.post?
      @format.update_attributes(params[:certif_format])
      flash[:notice] << _('Format updated successfully')
    end
  end

  def new_certif_format
    begin
      raise NotForUs unless request.post?
      @format = CertifFormat.new
      @format.update_attributes(params[:certif_format])
      @format.save!
      redirect_to :action => 'certif_format', :format_id => @format
    rescue NotForUs, ActiveRecord::RecordInvalid  => err
      flash[:error] << err.to_s
      redirect_to :action => 'certif_formats_list'
    end
  end

  def delete_certif_format
    @format.destroy
    redirect_to :action => 'certif_formats_list'
  end

  def add_certif_format_line
    begin
      raise NotForUs unless request.post?
      line = CertifFormatLine.new(params[:certif_format_line])
      line.certif_format = @format
      line.save!
    rescue NotForUs, ActiveRecord::RecordNotFound, NoMethodError => err
    end

    redirect_to :action => 'certif_format', :format_id => @format
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

  # Generate a sample certificate for the currently logged on user
  def gen_sample_certif
    draw_boxes = params[:pdf_draw_boxes].to_i == 1
    send_data(certificate_pdf_for([@user], @format, draw_boxes),
              :filename => 'test_certificate.pdf',
              :type => 'application/pdf')
  end

  protected
  # Genereates the PDF with the certificates for the people specified
  # as the first parameter, using the format specified as the second
  # parameter.
  def certificate_pdf_for(people, fmt, with_boxes=false)
    pdf = Prawn::Document.new(:page_layout => fmt.orientation.to_sym,
                              :page_size => fmt.paper_size,
                              :skip_page_creation => true)
#    pdf.stroke_color='000000' # Black is beautiful. Black for teh win!
    
    people.each do |person|
      pdf.start_new_page
    
      fmt.certif_format_lines.each do |line|
        # For the future, it might be nice to provide for nested
        # bounding boxes. As of right now, KISS.
        pdf.bounding_box([pdf.bounds.left + line.x_pos, 
                          pdf.bounds.bottom + line.y_pos],
                         :width => line.max_width,
                         :height => line.max_height) do
          # When testing formats, the user might want to show boxes
          # around each element
          if with_boxes
            stroke = pdf.stroke_color
            pdf.stroke_color = 'CBCBE1'
            pdf.stroke_bounds
            pdf.stroke_color = stroke
          end

          pdf.font_size line.font_size
          pdf.text(line.text_for(person, @conference), 
                   :align => line.justification.to_sym)
        end
      end
    end

    return pdf.render
  end

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
