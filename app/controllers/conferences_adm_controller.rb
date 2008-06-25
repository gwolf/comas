class ConferencesAdmController < Admin
  before_filter :get_conference, :only => [:show, :destroy, :people_list]
  Menu = [[_('Registered conferences'), :list]]

  def index
    redirect_to :action => 'list'
  end

  def list
    order = sort_for_fields(['conferences.id', 'name', 'begins', 
                             'reg_open_date'])

    @conferences = Conference.paginate(:all, :order => order, 
                                       :page => params[:page],
                                       :include => :people)
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

  private
  def get_conference
    return true if params[:id] and 
      @conference = Conference.find_by_id(params[:id])
    redirect_to :action => :list
  end
end
