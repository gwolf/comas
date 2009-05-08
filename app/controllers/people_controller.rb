class PeopleController < ApplicationController
  helper :conferences
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
      dest_url = session[:returnto] || url_for(:action => 'account')

      session[:user_id] = user.id
      redirect_to dest_url
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
  end

  def register
    if request.post?
      @person = Person.new(params[:person])
      if @person.save
        session[:user_id] = @person.id
        flash[:notice] << _('New person successfully registered')
        redirect_to :action => 'account'

        Notification.deliver_welcome(@person)

        return true
      else
        flash[:error] << [_('Could not register person: '),
                          @person.errors.full_messages].flatten
      end
    end
    redirect_to :action => 'new'
  end

  # Base data shown when logging in (i.e. account index)
  def account
    @upcoming = Conference.upcoming.paginate(:per_page=>5, 
                                             :page => params[:page])
    @mine = Conference.upcoming_for_person(@user)
  end

  # General personal information
  def personal
    return true unless request.post?
    if @user.update_attributes(params[:person])
      flash[:notice] << _('Your personal data has been updated successfully')
    else
      flash[:error] << _('Error updating your personal data: ') +
        @user.errors.full_messages.join('<br>')
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

  # Invite a friend (to a specific conference)
  def invite
    @my_confs = @user.upcoming_conferences
    return true unless request.post?

    begin
      conf = Conference.find_by_id(params[:dest_conf_id])
      Notification.deliver_conference_invitation(@user, params[:email], 
                                                 conf, params[:body])

      flash[:notice] << _('The requested e-mail was successfully sent')
      redirect_to :action => 'account'
    rescue ActiveRecord::RecordNotFound
      flash[:error] << _('Invalid conference requested')
    rescue Notification::MustSupplyBody
      flash[:error] << _('You must supply a body for your mail')
    rescue Notification::InvalidEmail
      flash[:error] << _('The specified e-mail address (%s) is not valid') %
        params[:email]
    end
  end

  ############################################################
  # Internal use...
  protected
  def clear_session
    session[:user_id] = nil
  end

  def check_auth
    public = [:login, :validate, :new, :register, :request_passwd]
    return true if public.include? request.path_parameters['action'].to_sym
  end
end
