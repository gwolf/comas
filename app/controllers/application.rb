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
    @menu = MenuTree.new(MenuItem.new( 'Conference listing',
                                       url_for(:controller => '/conferences',
                                               :action => 'list') ) )

    if @user.nil?
      @menu << MenuItem.new('Log in',
                            url_for(:controller => '/people', 
                                    :action => 'login')) <<
        MenuItem.new('New account',
                     url_for(:controller => '/people', :action => 'new'))
    else
      @menu << MenuItem.new('My account',
                            url_for(:controller => '/people',
                                    :action => 'account'))
      if ! @user.admin_tasks.empty?
        adm = MenuItem.new('Administration', nil, MenuTree.new)
        
        @user.admin_tasks.each do |at|
        adm.tree << MenuItem.new(at.name, 
                                 url_for(:controller => "/admin/#{at.name}"))
        end
        @menu << adm
      end
    end

  end
end
