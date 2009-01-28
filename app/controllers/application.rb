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
  before_filter :require_user_for_non_public_areas
  before_filter :check_auth
  before_filter :generate_menu
  before_filter :set_lang
  before_filter :set_pagination_labels
  before_filter :head_and_foot_text
  before_filter :setup_flash

  protected
  def get_user
    return false unless id = session[:user_id]
    @user = Person.find(id)
  end

  def require_user_for_non_public_areas
    return true if @user

    public = {:people => [:login, :logout, :validate, :new, :register, 
                          :request_passwd, :recover],
      :conferences => [:index, :list, :show, :proposals],
      :proposals => [:index, :list, :show, :by_author, :get_document]}

    ctrl = request.path_parameters['controller'].to_sym
    act = request.path_parameters['action'].to_sym

    return true if public.has_key?(ctrl) and public[ctrl].include?(act)
    redirect_to :controller => :people, :action => :login
    return false
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
      personal = MenuTree.new
      personal.add(_('Personal information'),
                   url_for(:controller => '/people', :action => 'personal'))
      personal.add(_('Change password'),
                   url_for(:controller => '/people', :action => 'password'))
      @user.can_submit_proposals_now? and
        personal.add(_('My proposals'),
                     url_for(:controller=>'/people', :action => 'proposals')) 
        

      @menu.add(_('My account'),
                url_for(:controller => '/people', :action => 'account'),
                personal)

      @user.admin_tasks.each do |task|
        begin
          control = "#{task.sys_name.camelcase}Controller".constantize
          menu = (control.constants.include?('Menu') ? 
                  control::Menu : []).map do |elem|
            MenuItem.new(elem[0], 
                         url_for(:controller => task.sys_name, :action => elem[1]))
          end
        rescue NameError
          # Probably caused by an unimplemented controller?
          menu = MenuItem.new(_'-*- Unimplemented')
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

  def head_and_foot_text
    @title = SysConf.value_for('title_text')
    @footer = SysConf.value_for('footer_text')
  end

  # Ensure there is a flash, and that it contains empty arrays for the
  # three message levels
  def setup_flash
    [:warning, :error, :notice].each {|level| flash[level] ||= []}
  end
end
