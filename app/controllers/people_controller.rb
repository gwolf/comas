class PeopleController < ApplicationController
  helper :conferences
  before_filter :get_invite, :only => [:claim_invite, :login, :new, :register,
                                       :account, :validate]

  ############################################################
  # Session handling
  def login
    clear_session
  end

  def logout
    clear_session
    flash[:notice] << _('Successfully logged out')
    redirect_to '/'
  end

  def validate
    user = Person.ck_login(params[:login], params[:passwd])
    if user
      session[:user_id] = user.id
      dest = {:action => 'account'}
      dest[:invite] = @invite.link if @invite
      redirect_to url_for(dest)
    else
      flash[:warning] << _('Incorrect user/password')
      redirect_to :action => 'login'
    end
  end

  ############################################################
  # Dealing with lost passwords...
  def request_passwd
    clear_session
    return true unless request.post?

    if person = Person.find_by_login(params[:login_or_email]) ||
        Person.find_by_email(params[:login_or_email])
      Notification.deliver_request_passwd(person, request.remote_ip)

      flash[:notice] << _('An email has been sent to you, with instructions ' +
                          'on how to enter the system and change your ' +
                          'password.')
      redirect_to :action => 'login'

    else
      flash[:error] << _('Nobody was found with the specified login or ' +
                         'E-mail address. Please make sure it was correctly ' +
                         'specified. Keep in mind this system is ' +
                         'case-sensitive.')
    end
  end

  def recover
    if person = RescueSession.person_for(params[:r_session])
      session[:user_id] = person.id
      session[:recovered_at] = Time.now
    else
      flash[:error] << _('Incorrect session specified - Remember session ' +
                         'URLs can be used only once')
      redirect_to :action => 'login'
    end
  end

  def rec_pass_chg
    if session[:recovered_at].nil?
      redirect_to :action => 'logout'
      flash[:error] << _('Invalid attempt to change password')
      return false
    end

    if session[:recovered_at] + 10.minutes < Time.now
      redirect_to :action => 'login'
      flash[:error] << _('Timeout waiting for your new password - You can ' +
                         'request for a new password recovery if needed.')
      return false
    end

    if !params[:new] or params[:new].empty? or
        params[:new] != params[:confirm]
      flash[:error] << _('New password does not match confirmation')
      render :action => recover
      return false
    end

    @user.passwd = params[:new]
    @user.save!
    flash[:notice] << _('Your password was successfully changed')
    redirect_to :action => 'account'
  end

  ############################################################
  # Person registration, personal data editing, ...
  def new
    @person = Person.new
    if @invite
      @conference = @invite.conference
      @accepts_reg = @conference.in_reg_period?
      @person.firstname = @invite.firstname
      @person.famname = @invite.famname
      @person.email = @invite.email
    end
  end

  def register
    if request.post?
      # Strip the photo pointer before creating the person, as
      # otherwise we will get an AssociationTypeMismatch
      photo = params[:person].delete(:photo) rescue nil
      @person = Person.new(params[:person])

      # Is this person a likely duplicate? Request confirmation before
      # continuing
      if !params.has_key?(:confirm_possible_dup) and
          @duplicates = @person.probable_duplicate?
        render :action => 'confirm_duplicate'
        return true
      end

      begin
        @person.transaction do
          @person.save!
          session[:user_id] = @person.id

          process_photo(@person, photo) if photo

          flash[:notice] << _('New person successfully registered')

          redirect_to :action => 'account'

          Notification.deliver_welcome(@person)
        end
      rescue ActiveRecord::RecordInvalid => msg
        flash[:error] << _('Error registering requested user') << msg
        render :action => 'new'
      end
    else
      # If we hit this method without being posted, pretend nothing
      # bad happened
      redirect_to :action => 'new'
    end
  end

  # Base data shown when logging in (i.e. account index)
  def account
    begin
      if @invite and (@invite.claimer.nil? or @invite.claimer == @user)
        @invite.claimer = @user
        @invite.save!
        @user.conferences << @invite.conference
        flash[:notice] << _('You have successfully registered for ' +
                            'conference <em>%s</em>') %
          @invite.conference.name
      end
    rescue ActiveRecord::RecordNotSaved => msg
      flash[:error] << _('Cannot register you for the conference you ' +
                         'were invited to: %s') % msg
    end

    @mine = Conference.upcoming_for_person(@user)
    @can_define_nametag = (@user and @user.has_admin_task?('sys_conf_adm'))
  end

  # General personal information
  def personal
    return true unless request.post?

    @user.transaction do
      if data = params[:person].delete(:photo) and !data.is_a? String
        process_photo(@user, data)
      end

      if @user.update_attributes(params[:person])
        redirect_to :action => 'account'
        flash[:notice] << _('Your personal data has been updated successfully')
      else
        flash[:error] << _('Error updating your personal data: ') +
          @user.errors.full_messages.join('<br>')
      end
    end
  end

  # Nametag printing
  def my_nametag
    nametag = CertifFormat.for_personal_nametag
    if nametag
      send_data(nametag.generate_pdf_for(@user),
                :filename => 'nametag.pdf', :type => 'application/pdf')
    else
      flash[:error] << _('No format has yet been defined for nametag printing')
      redirect_to :action => 'account'
    end
  end

  # Password change
  def password
    return true unless request.post?
    err = []

    err << _('All fields are required') if
      params[:current].blank? or params[:new].blank? or params[:confirm].blank?
    err << _('New password does not match confirmation') unless
      params[:new] == params[:confirm]
    err << _('Current password is not valid') unless
      Person.ck_login(@user.login, params[:current])

    @user.passwd = params[:new]
    @user.save or err << _('Error changing your password: ') +
      @user.errors.full_messages.join('<br/>')

    if !err.empty?
      flash[:error] += err
      return false
    end

    flash[:notice] << _('Your password was successfully changed')
    redirect_to :action => 'account'
  end

  # List my proposals
  def proposals
    @props = @user.proposals
  end

  # Public profile
  def profile
    @person = Person.find_by_id(params[:id],
                                :include => [:proposals, :conferences])
    if @person.nil?
      flash[:error] << _('Requested person is not registered')
      redirect_to '/'
    end
  end

  def get_photo
    @person = Person.find_by_id(params[:id])
    unless photo = @person.photo
      redirect_to :action => :profile, :id => @person
      return nil
    end
    size = params[:size] || 'normal'

    response.headers['Last-Modified'] = photo.updated_at.httpdate
    case size
    when 'thumb'
      img = photo.thumb
    else
      img = photo.data
    end
    send_data img, :type => 'image/jpeg', :disposition => 'inline'
  end

  # Invite a friend (to a specific conference)
  def invite
    return true unless request.post?

    begin
      conf = Conference.find_by_id(params[:dest_conf_id])
      if ! @user.conferences_for_invite.include?(conf)
        flash[:error] << _('You are not allowed to send invitations for ' +
                           'the specified conference.')
      end
      invite = ConfInvite.for(conf, @user, params[:email],
                              params[:firstname], params[:famname])
      Notification.deliver_conference_invitation(invite, params[:body])

      flash[:notice] << _('The requested e-mail was successfully sent')
      redirect_to :action => 'account'
    rescue ActiveRecord::RecordNotFound
      flash[:error] << _('Invalid conference requested')
    rescue Notification::MustSupplyBody
      flash[:error] << _('You must supply a body for your mail')
    rescue ActiveRecord::RecordInvalid, Notification::InvalidEmail
      flash[:error] << _('The specified e-mail address (%s) is not valid') %
        params[:email]
    end
  end

  def claim_invite
    if @user
      redirect_to :action => 'account', :invite => @invite.link
    else
      redirect_to :action => 'new', :invite => @invite.link
    end
  end

  ############################################################
  # Internal use...
  protected
  def clear_session
    session[:user_id] = nil
  end

  def check_auth
    public = [:login, :validate, :new, :register, :request_passwd,
              :claim_invite, :get_photo]
    return true if public.include? request.path_parameters['action'].to_sym
  end

  def get_invite
    @invite = ConfInvite.find_by_link(params[:invite])
  end

  def process_photo(person, photo)
    return nil if !photo or photo.is_a? String
    begin
      person.photo.destroy if person.has_photo?
      person_photo = person.build_photo
      person_photo.from_blob(photo.read)
      person_photo.save!
    rescue Magick::ImageMagickError
      flash[:error] << _('You have submitted an invalid document as ' +
                         'your photo. Please check its format and send ' +
                         'it again.')
      raise ActiveRecord::Rollback
    end
  end
end
