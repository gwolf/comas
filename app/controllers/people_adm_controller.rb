class PeopleAdmController < Admin
  before_filter :get_person, :only => [:show, :destroy]

  Menu = [[_('Registered people list'), :list],
          [_('By administrative task'), :by_task]]

  def index
    redirect_to :action => 'list'
  end

  def list
    order = sort_for_fields(['id', 'login', 'firstname', 'famname',
                             'last_login_at'])
    @filter_by = params[:filter_by]
    @people = Person.pag_search(@filter_by, 
                                :order => "people.#{order}",
                                :page => params[:page])
  end

  def by_task
    @tasks = AdminTask.find(:all, :include => :people)
  end

  def new
    @person = Person.new
  end

  def create
    @person = Person.new(params[:person])
    if @person.save
      flash[:notice] = _ 'New attendee successfully registered'
      redirect_to :action => 'list'
    else
      flash[:error] = [_("Error registering requested attendee: "),
                       @person.errors.full_messages ]
      render :action => 'new'
    end
  end

  def show
    return true unless request.post? 
    begin
      @person.transaction do
        @person.update_attributes(params[:person])
        # HABTM attributes: Clear them if they are empty
        [:conference_ids, :admin_task_ids].each do |rel|
          @person.send("#{rel}=", []) if ! params[:person][rel]
        end
        flash[:notice] = _('Person data successfully updated')
      end
   rescue TypeError => err
     flash[:error] = _("Error recording requested data: %s") % err
    end
  end

  def destroy
    if request.post? 
      if @person != @user and @person.destroy
        flash[:notice] = _ 'Successfully removed requested attendee'
      else
        flash[:error] = [_('Error removing requested attendee: '),
                         @person.errors.full_messages]
      end
    else
      flash[:error] = _'Invocation error'
    end

    redirect_to :action => 'list'
  end

  private
  def get_person
    return true if params[:id] and @person = Person.find_by_id(params[:id])
    redirect_to :action => :list
  end
end
