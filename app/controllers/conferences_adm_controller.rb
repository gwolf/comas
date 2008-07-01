class ConferencesAdmController < Admin
  before_filter :get_conference, :except => [:index, :list, :new, :create]
  Menu = [[_('Registered conferences'), :list]]

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
      flash[:notice] = _ 'New conference successfully registered'
      redirect_to :action => 'list'
    else
      flash[:error] = [_("Error registering requested conference: "),
                       @conference.errors.full_messages ]
      render :action => 'new'
    end
  end

  def show
    if request.post? and @conference.update_attributes(params[:conference])
      flash[:warning] = _('Conference data successfully updated')
    end
  end

  def destroy
    redirect_to :action => 'list'

    if request.post? 
      if @conference.destroy
        flash[:notice] = _ 'Successfully removed requested conference'
      else
        flash[:error] = [_('Error removing requested conference: '),
                         @conference.errors.full_messages]
      end
    else
      flash[:error] = _'Invocation error'
    end
  end

  def people_list
    order = sort_for_fields(['famname'])

    @people = Person.paginate(:all, :order => order, :include => :conferences,
                              :conditions => ['conferences.id = ?', @conference],
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
      flash[:notice] = _('The requested timeslot was successfully created')
    else 
      flash[:error] = _('Error creating the requested timeslot:<br/> %s') %
        ts.errors.full_messages.join("<br/>")
    end
  end

  def destroy_timeslot
    redirect_to :action => :timeslots, :id => @conference.id

    if tslot = Timeslot.find_by_id(params[:timeslot_id]) and
        tslot.conference == @conference and tslot.destroy
      flash[:notice] = _('The requested timeslot was successfully deleted')
    else
      flash[:error] = _('Could not find requested timeslot (%d) for ' +
                        'deletion - Maybe it was already deleted?') % 
        params[:timeslot_id]
    end
  end

  ############################################################
  private
  def get_conference
    return true if params[:id] and 
      @conference = Conference.find_by_id(params[:id])
    redirect_to :action => :list
  end
end
