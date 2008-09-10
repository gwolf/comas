class ConferencesController < ApplicationController
  before_filter :get_conference, :except => [:index, :list]
  helper :proposals

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
    @can_edit = true if @user and @user.has_admin_task? 'conferences_adm'
  end

  def proposals
    # We could just use @conference.proposals, but... lets paginate
    # nicely and bring all the information at once!
    @props = Proposal.list_paginator(:page => params[:page],
                                     :per_page => params[:per_page]|| 20,
                                     :conditions => ['conference_id = ?',
                                                     @conference.id])
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
    return unless @user.conferences.include? @conference

    if props = @conference.proposals_by_person(@user) and
        !props.empty?
      flash[:error] = _('You have %d proposals registered for this ' +
                        'conference. Please withdraw them before ' +
                        'unregistering.') % props.size
      return false
    end

    if @user.conferences.delete @conference
      flash[:notice] = _('You have successfully unregistered from ' +
                         'conference "%s"') % @conference.name
    else
      flash[:error] = _('Could not unregister you from conference %s: %s') %
        [@conference.name, @user.errors.full_messages]
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
    public = [:index, :list, :show, :proposals]
    return true if public.include? request.path_parameters['action'].to_sym
  end
end
