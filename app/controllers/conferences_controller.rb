class ConferencesController < ApplicationController
  before_filter :get_conference, :except => [:index, :list]
  before_filter :rss_links
  helper :proposals

  def index
    redirect_to :action => :list
  end

  def list
    # Both parameters? No worry - hide kills show ;-)
    session[:conf_list_include_past] = true if params[:show_old]
    session[:conf_list_include_past] = false if params[:hide_old]

    # Did we get a request to filter by a certain category?
    # (categories must be existing conference catalogs)
    cond_k = []
    cond_v = []
    @cond = []
    Conference.catalogs.each do |catalog, klass|
      next unless params.keys.include? catalog
      next if params[catalog].nil? or params[catalog].empty?
      value = params[catalog].to_i
      item = klass.find_by_id(value)
      next unless item

     @cond << '%s: %s' % [Translation.for(catalog.humanize),
                          Translation.for(item.name)]
      cond_k << '%s = ?' % catalog
      cond_v << value
    end

    if ! session[:conf_list_include_past]
      cond_k << 'finishes >= ?'
      cond_v << Date.today
    end

    @rss_links[_('Conferences where %s') %
               @cond.join(', ')] = rss_link_for(params) unless @cond.empty?

    cond = [cond_k.join(' and '), cond_v].flatten
    per_page = params[:per_page] || 5

    @conferences = Conference.paginate(:per_page => per_page,
                                       :order => :begins,
                                       :page => params[:page],
                                       :conditions => cond)

    respond_to do |fmt|
      fmt.html
      fmt.rss
    end
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

  def rss_links
    @rss_links = {
      _('Upcoming conferences') => rss_link_for(:hide_old => 1)
    }
  end

  def rss_link_for(params={})
    url_for(params.merge('action' => 'list',
                         'format' => 'rss',
                         'lang' => Locale.get))
  end
end
