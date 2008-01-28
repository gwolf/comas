# Filters added to this controller apply to all controllers in the application.
# Likewise, all the methods added will be available for all controllers.

class ApplicationController < ActionController::Base
  # Pick a unique cookie name to distinguish our session data from others'
  session :session_key => '_comas_session_id'

  before_filter :generate_menu

  private
  def generate_menu
    @menu = [{:label => 'Conference listing', 
               :link => {:controller => 'conferences', :action => 'list'}},
             {:label => 'Log in',
               :link => {:controller => 'person', :action => 'login'}},
            ]
  end
end
