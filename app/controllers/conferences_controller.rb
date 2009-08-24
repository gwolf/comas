class ConferencesController < ApplicationController
  before_filter :get_conference, :except => [:index, :list, :rss]
  helper :proposals

  RssLinks = {'latest' => _('Latest registered conferences'),
    'upcoming' => _('Upcoming conferences'),
    'reg_open' => _('Conferences for which registration is open'),
    'cfp_open' => _('Conferences on which Call For Papers is open')
  }

  def index
    redirect_to :action => :list
  end

  def list
    # Both parameters? No worry - hide kills show ;-)
    session[:conf_list_include_past] = true if params[:show_old]
    session[:conf_list_include_past] = false if params[:hide_old]

    @rss_links = RssLinks

    per_page = params[:per_page] || 5
    @conferences = if session[:conf_list_include_past]
                     Conference.paginate(:per_page => per_page,
                                         :order => :begins,
                                         :page => params[:page])
                   else
                     Conference.upcoming.paginate(:page => params[:page],
                                                  :per_page => per_page)
                   end
  end

  def rss
    conf = []
    how_many = params[:how_many].to_i
    how_many = 10 if how_many == 0
    @rss_descr = RssLinks[params[:id]]

    case params[:id]
    when 'latest'
      conf = Conference.find(:all,
                             :order => 'id DESC')
    when 'upcoming'
      conf = Conference.upcoming
    when 'reg_open'
      conf = Conference.in_reg_period
    when 'cfp_open'
      conf = Conference.in_cfp_period
    else
      raise NoMethodError, _('No such RSS defined') % params[:id]
    end
    @conferences = conf[0..how_many-1]
  end

  def show
    @can_edit = true if @user and @user.has_admin_task? :conferences_adm
    @props_to_show = listable_proposals
  end

  def proposals
    @props = listable_proposals.
      paginate(:page => params[:page],
               :per_page => params[:per_page] || 20,
               :include => [:authorships, :people, :prop_type],
               :order => 'title, authorships.position')
    if @props.empty?
      redirect_to :action => 'show', :id => @conference.id
      flash[:warning] << _('No listable proposals found for this conference')
    end
  end

  ############################################################
  # Person sign up for/removal
  def sign_up
    registrations_sanity_checks or return false

    if @user.register_for(@conference)
      flash[:notice] << _('You have successfully registered for ' +
                          'conference "%s"') % @conference.name
    else
      flash[:error] << _('Could not register you for conference %s: %s') %
        [@conference.name, @user.errors.full_messages]
    end
  end

  def unregister
    registrations_sanity_checks or return false

    # Avoid silly mistakes due to reloads
    return unless @user.conferences.include? @conference

    if props = @conference.proposals_by_person(@user) and
        !props.empty?
      flash[:error] << _('You have %d proposals registered for this ' +
                         'conference. Please withdraw them before ' +
                         'unregistering.') % props.size
      return false
    end

    if @user.conferences.delete @conference
      flash[:notice] << _('You have successfully unregistered from ' +
                          'conference "%s"') % @conference.name
    else
      flash[:error] << _('Could not unregister you from conference %s: %s') %
        [@conference.name, @user.errors.full_messages]
    end
  end

  protected
  def listable_proposals
    return @conference.proposals if @user and
      @user.has_admin_task? :academic_adm
    @conference.publicly_showable_proposals
  end

  def registrations_sanity_checks
    redirect_to :controller => 'people', :action => 'account'
    return false unless request.post?
    return false unless @user
    reject = false

    if @conference.invite_only?
      flash[:error] << _('This conference is by invitation only.')
      reject = true
    end

    if !@conference.accepts_registrations?
      flash[:error] << _('This conference does not currently accept ' +
                         'changing your registration status - please visit ' +
                         'its information page for more details')
      reject = true
    end

    return !reject
  end

  def get_conference
    begin
      if params[:id]
        conf = params[:id]
        @conference = Conference.find(conf)
      elsif params[:short_name]
        conf = params[:short_name]
        @conference = Conference.find_by_short_name(conf)
      end
      raise ActiveRecord::RecordNotFound unless @conference
    rescue ActiveRecord::RecordNotFound
      flash[:error] << _('Invalid conference <em>%s</em> requested') % conf
      redirect_to :action => :list
      return false
    end
  end

  def check_auth
    public = [:index, :list, :show, :proposals]
    return true if public.include? request.path_parameters['action'].to_sym
  end
end
