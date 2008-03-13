# Filters added to this controller apply to all controllers in the application.
# Likewise, all the methods added will be available for all controllers.

class ApplicationController < ActionController::Base
  # Pick a unique cookie name to distinguish our session data from others'
  session :session_key => '_comas_session_id'

  before_filter :get_user
  before_filter :check_auth
  before_filter :generate_menu

  protected
  def get_user
    return false unless id = session[:user_id]
    @user = Person.find(id)
  end

  def check_auth
    contr = request.path_parameters['controller']
    raise NotImplementedError, "Controller #{contr} must implement check_auth"
  end

  def generate_menu
    @menu = [{:label => 'Conference listing', 
               :link => {:controller => 'conferences', :action => 'list'}}]

    if @user.nil?
      @menu << {:label => 'Log in',
        :link => {:controller => 'people', :action => 'login'}}
    else
      @menu << {:label => 'My account',
        :link => {:controller => 'people', :action => 'account'}}
    end
  end

end
