class ConferencesAdmController < Admin
  before_filter :get_conference, :except => [:index, :list, :new, :create,
                                             :mail_attendees, :confs_by_name]
  helper :conferences
  Menu = [[_('Registered conferences'), :list],
          [_('Register a new conference'), :new],
          [_('Mail attendees'), :mail_attendees]]

  def index
    redirect_to :action => 'list'
  end

  def list
    order = sort_for_fields(['begins desc', 'conferences.id', 'name',
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
    @conference.transaction do
      if request.post? and @conference.update_attributes(params[:conference])
        if upload = params[:data] and !upload.is_a? String
          begin
            img = upload.read
            logo = Logo.new(:conference => @conference)
            logo.process_img(img)
          rescue Magick::ImageMagickError => err
            flash[:error] << _('The uploaded file could not be processed ' +
                               'as an image: %s') % err.message
            raise ActiveRecord::Rollback
          end
        end
        flash[:warning] << _('Conference data successfully updated')
        redirect_to( :controller => 'conferences',
                     :action => 'show',
                     :id => @conference )
      end
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
        params[:body].nil? or params[:body].empty? or
        params[:dest_conf_ids].nil? or params[:dest_conf_ids].empty?
      flash[:error] << _('You must specify email title and body, and select ' +
                         'at least one conference to mail to.')
      return false
    end

    begin
      confs = params[:dest_conf_ids].map {|c| Conference.find_by_id(c)}
    rescue ActiveRecord::RecordNotFound, ActiveRecord::StatementInvalid => err
      flash[:error] << _('Invalid conference specified: %s') % err.message
      return false
    end

    # Only one mail per person, no matter to how many conferences he
    # has registered to
    rcpts = confs.map {|c| c.people_for_mailing}.flatten.uniq
    rcpts.each do |rcpt|
      begin
        Notification.deliver_conf_attendees_mail(@user, rcpt, confs,
                                       params[:title], params[:body])
      rescue Notification::InvalidEmail
        flash[:warning] << _('User %s (ID: %s) is registered with an ' +
                              'invalid email address (%s). Skipping...') %
          [rcpt.name, rcpt.id, rcpt.email]
      end
    end

    if rcpts.empty?
      flash[:notice] << _('No registered attendees for the requested ' +
                          'conferences have chosen to receive mails - ' +
                          'Not sending.')
    else
      flash[:notice] << _('The %d requested mails have been sent.')%rcpts.size
    end
    redirect_to :action => 'list'
  end

  def confs_by_name
    if ! request.xhr?
      redirect_to :action => 'mail_attendees'
      return false
    end
    qry = params[:conf_name] || ''
    @conferences = Conference.all(:conditions => ['name ~* ?', qry])
    render :partial => 'conferences_ckbox_table'
  end

  ############################################################
  private
  def get_conference
    return true if params[:id] and
      @conference = Conference.find_by_id(params[:id])
    redirect_to :action => :list
  end
end
