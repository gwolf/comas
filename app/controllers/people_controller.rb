class PeopleController < ApplicationController
  helper :conferences
  ############################################################
  # Session handling
  def login
    clear_session
  end

  def logout
    clear_session
    flash[:notice] = _ 'Successfully logged out'
    redirect_to '/'
  end

  def validate
    user = Person.ck_login(params[:login], params[:passwd])
    if user
      dest_url = session[:returnto] || url_for(:action => 'account')

      session[:user_id] = user.id
      redirect_to dest_url
    else
      flash[:warning] = _ 'Incorrect user/password'
      redirect_to :action => 'login'
    end
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
        flash[:notice] = _ 'New person successfully registered'
        redirect_to :action => 'account'

        Notification.deliver_welcome(@person)

        return true
      else
        flash[:error] = [_('Could not register person: '),
                         @person.errors.full_messages].flatten
      end
    end
    redirect_to :action => 'new'
  end

  # Base data shown when logging in (i.e. account index)
  def account
    @upcoming = Conference.upcoming(:per_page=>5, :page => params[:page])
    @mine = Conference.upcoming_for_person(@user)
  end

  # General personal information
  def personal
    return true unless request.post?
    if @user.update_attributes(params[:person])
      flash[:notice] = _'Your personal data has been updated successfully'
    else
      flash[:error] = _('Error updating your personal data: ') +
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
      flash[:error] = err
      return false
    end

    flash[:notice] = _('Your password was successfully changed')
    redirect_to :action => 'account'
  end

  # List my proposals
  def proposals
    @props = @user.proposals
  end

  ############################################################
  # Internal use...
  protected
  def clear_session
    session[:user_id] = nil
  end

  def check_auth
    public = [:login, :validate, :new, :register]
    return true if public.include? request.path_parameters['action'].to_sym
  end
end
