# Filters added to this controller apply to all controllers in the application.
# Likewise, all the methods added will be available for all controllers.
require 'pseudo_gettext'

class ApplicationController < ActionController::Base
  init_gettext 'comas'

  # Load the Rails Date Kit helpers
  # (http://www.methods.co.nz/rails_date_kit/rails_date_kit.html)
  helper :date

  # Pick a unique cookie name to distinguish our session data from others'
  session :session_key => '_comas_session_id'

  before_filter :get_user
  before_filter :check_auth
  before_filter :generate_menu
  before_filter :set_lang
  before_filter :set_pagination_labels

  protected
  def get_user
    return false unless id = session[:user_id]
    @user = Person.find(id)
  end

  def check_auth
    contr = request.path_parameters['controller']
    raise NotImplementedError, _("Controller %s must implement check_auth") %
      contr
  end

  # The controller for each of the admin tasks can include a Menu
  # constant. This constant will be an array, with each element being
  # an array with two elements: The name to display for the option to
  # show and the name of one of its actions. Thus, in order to provide
  # links in the main menu to the 'list' and 'status' actions of a
  # controller:
  #
  #   def SomeThingController < Admin
  #     Menu = [[_('General list'), :list], [_('Status overview'), :status]]
  # 
  # Yes, don't forget i18n.
  def generate_menu
    @menu = MenuTree.new
    @menu.add( _('Conference listing'),
               url_for(:controller => '/conferences', :action => 'list') )

    if @user.nil?
      @menu.add(_('Log in'),
                url_for(:controller => '/people', :action => 'login'))
      @menu.add(_('New account'),
                url_for(:controller => '/people', :action => 'new'))
    else
      @menu.add(_('My account'),
                url_for(:controller => '/people', :action => 'account'))

      @user.admin_tasks.each do |task|
        control = "#{task.sys_name.camelcase}Controller".constantize
        menu = (control.constants.include?('Menu') ? 
                control::Menu : []).map do |elem|
          MenuItem.new(elem[0], 
                       url_for(:controller => task.sys_name, :action => elem[1]))
        end

        @menu.add(_(task.qualified_name), nil, MenuTree.new(menu))
      end
    end
  end

  def set_lang
    return true unless lang = params[:lang]
    cookies[:lang] = {:value => lang, :expires => Time.now+1.day, :path => '/'}
  end

  def set_pagination_labels
    { :prev_label   => _('&laquo; Previous'),
      :next_label   => _('Next &raquo;') }.each do |k, v|
      WillPaginate::ViewHelpers.pagination_options[k] = v
    end
  end

  # sortable: List of fields according to which the results can be sorted.
  def sort_for_fields(sortable)
    key = [:controller, :action].map {|k| request.path_parameters[k]}.join('/')
    session[key] ||= {}

    if params[:sort_by] and sortable.include? params[:sort_by].to_s
      session[key][:sort_by] = params[:sort_by]
    end
    session[key][:sort_by] ||= sortable[0]

    session[key][:sort_by]
  end
end
