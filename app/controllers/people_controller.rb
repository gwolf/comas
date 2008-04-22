class PeopleController < ApplicationController
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
        return true
      else
        flash[:error] = [_('Could not register person: '),
                         @person.errors.full_messages].flatten
      end
    end
    redirect_to :action => 'new'
  end

  def account
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
