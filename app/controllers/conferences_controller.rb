class ConferencesController < ApplicationController
  before_filter :get_conference, :except => [:index, :list]

  def index
    redirect_to :action => :list
  end

  def list
    # Both parameters? No worry - hide kills show ;-)
    session[:conf_list_include_past] = true if params[:show_old]
    session[:conf_list_include_past] = false if params[:hide_old]

    per_page = params[:per_page] || 5
    method = session[:conf_list_include_past] ? :paginate : :upcoming
    @conferences = Conference.send(method, 
                                   :per_page => per_page, 
                                   :order => :begins,
                                   :page => params[:page])
  end

  def show
  end

  ############################################################
  # Person sign up for/removal
  def sign_up
    registrations_sanity_checks or return false

    # Avoid silly mistakes due to reloads
    return if @user.conferences.include? @conference
    if @user.conferences << @conference
      flash[:notice] = _('You have successfully registered for ' +
                         'conference "%s"') % @conference.name
    else
      flash[:error] = _('Could not register you for conference %s: %s') %
        [@conference.name, @user.errors.full_messages]
    end
  end

  def unregister
    registrations_sanity_checks or return false

    # Avoid silly mistakes due to reloads
    return unless @user.conferences.include? conf

    if @user.conferences.delete conf
      flash[:notice] = _('You have successfully unregistered from ' +
                         'conference "%s"') % conf.name
    else
      flash[:error] = _('Could not unregister you from conference %s: %s') %
        [conf.name, @user.errors.full_messages]
    end
  end

  protected
  def registrations_sanity_checks
    redirect_to :controller => 'people', :action => 'account'
    return false unless request.post?
    return false unless @user

    if !@conference.accepts_registrations?
      flash[:error] = [_('This conference does not currently accept ' +
                         'changing your registration status - please visit ' +
                         '%s for more details') %
                       link_to(_('its information page'), 
                               :action => show, :id => @conference)]
      return false
    end
    return true
  end

  def get_conference
    begin
      @conference = Conference.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      flash[:error] = _'Invalid conference requested'
      redirect_to :action => :list
      return false
    end
  end

  def check_auth
    public = [:index, :list, :show]
    return true if public.include? request.path_parameters['action'].to_sym
  end
end
