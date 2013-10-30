# -*- coding: utf-8 -*-
# Filters added to this controller apply to all controllers in the application.
# Likewise, all the methods added will be available for all controllers.
require 'pseudo_gettext'

class ApplicationController < ActionController::Base
  include GetTextRails
  protect_from_forgery # See ActionController::RequestForgeryProtection for details
  exempt_from_layout :rxml

  before_init_gettext :set_lang

  # Load the Rails Date Kit helpers
  # (http://www.methods.co.nz/rails_date_kit/rails_date_kit.html)
  helper :date

  # Pick a unique cookie name to distinguish our session data from others'
  session :session_key => '_comas_session_id'

  before_filter :get_user
  before_filter :require_user_for_non_public_areas
  before_filter :check_auth
  before_filter :generate_menu
  before_filter :set_pagination_labels
  before_filter :head_and_foot_text
  before_filter :setup_flash

  layout :choose_layout

  protected
  def get_user
    return false unless id = session[:user_id]
    @user = Person.find_by_id(id)
  end

  def require_user_for_non_public_areas
    return true if @user

    public = {:people => [:login, :logout, :validate, :new, :register,
                          :request_passwd, :recover, :profile, :claim_invite,
                          :get_photo],
      :conferences => [:index, :list, :show, :proposals],
      :proposals => [:index, :list, :show, :by_author, :get_document],
      :logos => [:data, :thumb, :medium]}

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
  #
  # Menu items that have their link set to nil will be shown as labels
  # only; menu items can stack other menus as their third parameter, thus:
  #
  #   def ComplexNestedController < Admin
  #     Menu = [[_('General actions'), nil,
  #               [_('Do something'), :do_it],
  #               [_('Cancel something'), :cancel_it],
  #        (...)
  #            ]
  #
  # Will do... Well, what you would expect it to ;-)
  def generate_menu
    @menu = MenuTree.new
    @menu.add( _('Conference listing'),
               url_for(:controller => '/conferences', :action => 'list') )
    # A link will be generated here and at some other views all over,
    # so we declare a dirty, ugly @link_to_nametags
    @link_to_nametag = CertifFormat.for_personal_nametag

    if @user.nil?
      @menu.add(_('Log in'),
                url_for(:controller => '/people', :action => 'login'))
      @menu.add(_('New account'),
                url_for(:controller => '/people', :action => 'new'))
    else
      personal = MenuTree.new
      personal.add(_('Basic information'),
                   url_for(:controller => '/people', :action => 'account'))
      personal.add(_('Update your personal information'),
                   url_for(:controller => '/people', :action => 'personal'))
      personal.add(_('Change password'),
                   url_for(:controller => '/people', :action => 'password'))
      personal.add(_('My public profile'),
                   url_for(:controller => '/people', :action => 'profile',
                        :id => @user.id))
      @link_to_nametag and personal.add(_('Generate nametag'),
                   url_for(:controller => '/people', :action => 'my_nametag'))
      @user.can_submit_proposals_now? and
        personal.add(_('My proposals'),
                     url_for(:controller=>'/people', :action => 'proposals'))
      @user.conferences.size > 0 and
        personal.add(_('Invite a friend'),
                     url_for(:controller=>'/people', :action => 'invite'))

      @menu.add(_('My account'), nil, personal)

      @user.admin_tasks.sort_by(&:sys_name).each do |task|
        begin
          control = "#{task.sys_name.camelcase}Controller".constantize
          menu = menu_subtree_for((control.constants.include?('Menu') ?
                                   control::Menu : []), task)
        rescue NameError
          # Probably caused by an unimplemented controller? A
          # controller which does not implement a menu?
          menu = menu_subtree_for([[_'-*- Unimplemented']], task)
        end

        @menu.add(Translation.for(task.qualified_name),
                  nil, menu)
      end
    end
  end

  def menu_subtree_for(tree, task)
    menu = MenuTree.new

    tree.each do |elem|
      link = url_for(:controller => task.sys_name,
                     :action => elem[1]) if elem[1]
      sub = menu_subtree_for(elem[2], task) if elem[2]
      menu.add(_(elem[0]), link, sub)
    end

    menu
  end

  def set_lang
    bindtextdomain 'comas'
    # Ensure gettext gets a string
    params[:lang] = params[:lang].to_s; params[:lang] = nil if params[:lang].empty?
    lang = cookies[:lang]
    set_lang = params[:lang]

    # No language specified so far? Go for the defaults
    if (lang.nil? or lang.empty?)
      set_lang = SysConf.value_for('default_lang') || 'en'
    end

    if (set_lang and set_lang != lang)
      cookies['lang'] = {:value => set_lang,
        :expires => Time.now+1.day,
        :path => '/'}
    end
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

  def choose_layout
    # Default layout is Rails' default ('application') if SysConf does
    # not instruct us otherwise
    default = 'application'
    layout_dir = File.join(RAILS_ROOT, 'app/views/layouts')

    return default unless sys_layout = SysConf.value_for('system_layout')

    matching = Dir.open(layout_dir).select {|lay|
      lay[0..(sys_layout.size)] == '%s.' % sys_layout }
    return sys_layout unless matching.empty?

    # We are still just declaring the Application class. Not even
    # the Flash is set up - We can only report this to the default
    # logger.
    RAILS_DEFAULT_LOGGER.warn _('Requested layout "%s" not found, ' +
                                'in "%s" - using default layout') %
      [sys_layout, layout_dir]
    return default
  end
end
