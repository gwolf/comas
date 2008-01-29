# Filters added to this controller apply to all controllers in the application.
# Likewise, all the methods added will be available for all controllers.

class ApplicationController < ActionController::Base
  # Pick a unique cookie name to distinguish our session data from others'
  session :session_key => '_comas_session_id'

  before_filter :set_locale
  before_filter :get_user
  before_filter :generate_menu

  private
  def get_user
    return false unless id = session[:user_id]
    @user = Person.find(id)
  end

  def generate_menu
    @menu = [{:label => 'Conference listing', 
               :link => {:controller => 'conferences', :action => 'list'}},
             {:label => 'Log in',
               :link => {:controller => 'people', :action => 'login'}},
            ]
  end

  def set_locale
    # Set to the locale to whatever is specified in the :lang parameter. Not 
    # set? Ok, then go to the last locale set in the session. Not set? Bah, 
    # default to English.
    default = 'en-US'

    locale = params[:lang] || session[:lang] || default
    locale = default unless RFC_3066.valid?(locale)

    Locale.set(locale)
    session[:lang] = locale
    true
  end
end
