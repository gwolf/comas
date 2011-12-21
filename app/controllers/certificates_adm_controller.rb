class CertificatesAdmController < Admin
  class NotForUs < Exception; end
  Menu = [[_('Certificate formats'), :list]
         ]

  before_filter :get_format, :except => [:list, :new]
  before_filter :get_conference, :only => [:gen_sample, :for_person]
  before_filter :get_person, :only => [:for_person]

  # Generates a certificate for the specified person / conference /
  # format
  def for_person
    send_data(@format.generate_pdf_for(@person, @conference),
              :filename => 'certificate.pdf',
              :type => 'application/pdf')
  end

  # Lists the registered certificate formats
  def list
    @formats = CertifFormat.paginate(:all, :order => :id,
                                     :include => :certif_format_lines,
                                     :page => params[:page])
    @new_fmt = CertifFormat.new
  end

  def show
    @new_line = CertifFormatLine.new
    @conferences = Conference.find(:all)
    @units = CertifFormat.full_units
    if request.post?
      @format.update_attributes(params[:certif_format])
      flash[:notice] << _('Format updated successfully')
    end
  end

  def new
    begin
      raise NotForUs unless request.post?
      @format = CertifFormat.new
      @format.update_attributes(params[:certif_format])
      @format.save!
      redirect_to :action => 'certif_format', :id => @format
    rescue NotForUs, ActiveRecord::RecordInvalid  => err
      flash[:error] << err.to_s
      redirect_to :action => 'list'
    end
  end

  def delete
    @format.destroy
    redirect_to :action => 'list'
  end

  def add_line
    begin
      raise NotForUs unless request.post?
      line = CertifFormatLine.new(params[:certif_format_line])
      line.certif_format = @format
      line.save!
    rescue NotForUs, ActiveRecord::RecordNotFound, NoMethodError => err
    end

    redirect_to :action => 'show', :id => @format
  end

  def delete_line
    begin
      raise NotForUs unless request.post?
      line = CertifFormatLine.find(params[:line_id])
      raise NotForUs unless line.certif_format = @format
      line.destroy
    rescue NotForUs, ActiveRecord::RecordNotFound, NoMethodError
    end

    redirect_to :action => 'show', :id => @format
  end

  # Generate a sample certificate for the currently logged on user
  def gen_sample
    draw_boxes = params[:pdf_draw_boxes].to_i == 1
    send_data(@format.generate_pdf_for(@user, @conference, draw_boxes),
              :filename => 'test_certificate.pdf',
              :type => 'application/pdf')
  end

  protected
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
    @format = CertifFormat.find_by_id(params[:id],
                                      :include => :certif_format_lines)
    return true if @format
    flash[:error] << _('Invalid format specified')
    false
  end
end
