class ConferencesAdmController < Admin
  before_filter :get_conference, :except => [:index, :list, :new, :create, 
                                             :mail_attendees]
  Menu = [[_('Registered conferences'), :list],
          [_('Register a new conference'), :new],
          [_('Mail attendees'), :mail_attendees]]

  def index
    redirect_to :action => 'list'
  end

  def list
    order = sort_for_fields(['conferences.id', 'name', 'begins', 
                             'reg_open_date'])

    @conferences = Conference.paginate(:all, :order => order, 
                                       :page => params[:page],
                                       :include => [:people, :timeslots])
  end

  def new
    @conference = Conference.new
  end

  def create
    @conference = Conference.new(params[:conference])
    if @conference.save
      flash[:notice] << _('New conference successfully registered')
      redirect_to :action => 'list'
    else
      flash[:error] << [_("Error registering requested conference: "),
                       @conference.errors.full_messages ]
      render :action => 'new'
    end
  end

  def show
    if request.post? and @conference.update_attributes(params[:conference])
      flash[:warning] << _('Conference data successfully updated')
      redirect_to( :controller => 'conferences',
                   :action => 'show', 
                   :id => @conference )
    end
  end

  def destroy
    redirect_to :action => 'list'

    if request.post? 
      if @conference.destroy
        flash[:notice] << _('Successfully removed requested conference')
      else
        flash[:error] << [_('Error removing requested conference: '),
                          @conference.errors.full_messages]
      end
    else
      flash[:error] << _('Invocation error')
    end
  end

  def people_list
    order = sort_for_fields(['famname'])

    @people = @conference.people.paginate(:all, :order => order, 
                                          :page => params[:page])
  end

  ############################################################
  # Timeslots management
  def timeslots
    @tslots = Timeslot.paginate(:all, :page => params[:page],
                                :per_page => 10,
                                :include => [:attendances, :room],
                                :conditions => ['conference_id = ?',
                                                @conference.id],
                                :order => 'start_time')
    @new_ts = Timeslot.new(:start_time => @conference.begins+10.hours,
                           :conference_id => @conference.id)
  end

  def create_timeslot
    redirect_to :action => :timeslots, :id => @conference.id

    ts = Timeslot.new(params[:timeslot])
    ts.conference = @conference
    if ts.save
      flash[:notice] << _('The requested timeslot was successfully created')
    else 
      flash[:error] << _('Error creating the requested timeslot:<br/> %s') %
        ts.errors.full_messages.join("<br/>")
    end
  end

  def destroy_timeslot
    redirect_to :action => :timeslots, :id => @conference.id

    if tslot = Timeslot.find_by_id(params[:timeslot_id]) and
        tslot.conference == @conference and tslot.destroy
      flash[:notice] << _('The requested timeslot was successfully deleted')
    else
      flash[:error] << _('Could not find requested timeslot (%d) for ' +
                         'deletion - Maybe it was already deleted?') % 
        params[:timeslot_id]
    end
  end

  ############################################################
  # Mass-mailing the registered people for a conference
  def mail_attendees
    @conferences = Conference.upcoming + Conference.past
    return true unless request.post?

    if params[:title].nil? or params[:title].empty? or 
        params[:body].nil? or params[:body].empty?
      flash[:error] << _('You must specify both email title and body')
      return false
    end

    unless conf = Conference.find_by_id(params[:dest_conf_id])
      flash[:error] << _('Invalid conference specified')
      return false
    end

    rcpts = conf.people_for_mailing
    rcpts.each do |rcpt|
      begin
        Notification.deliver_conf_attendees_mail(@user, rcpt, conf,
                                       params[:title], params[:body])
      rescue Notification::InvalidEmail
        flash[:warning] << _('User %s (ID: %s) is registered with an ' +
                              'invalid email address (%s). Skipping...') %
          [rcpt.name, rcpt.id, rcpt.email]
      end
    end

    if rcpts.empty?
      flash[:notice] << _('No registered attendees for %s have chosen to '+
                          'receive mails - Not sending.') % conf.name
    else
      flash[:notice] << _('The %d requested mails for "%s" attendees have ' +
                          'been sent.') % [rcpts.size, conf.name]
    end
    redirect_to :action => 'list'
  end

  ############################################################
  private
  def get_conference
    return true if params[:id] and 
      @conference = Conference.find_by_id(params[:id])
    redirect_to :action => :list
  end
end
