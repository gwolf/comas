class PeopleAdmController < Admin
  before_filter :get_person, :only => [:show, :destroy]
  Menu = [[_('Registered people list'), :list],
          [_('By administrative task'), :by_task]]

  def index
    redirect_to :action => 'list'
  end

  def list
    session[:people_admin] ||= {}
    sortable = [:id, :firstname, :famname, :person_type_id, :last_login_at]

    if params[:sort_by] and sortable.include? params[:sort_by].to_sym
      session[:people_admin][:sort_by] = params[:sort_by]
    end
    session[:people_admin][:sort_by] ||= sortable[0]

    order = session[:people_admin][:sort_by]

    @people = Person.paginate(:all, :order => "people.#{order}",
                              :include => :person_type, :page => params[:page])
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
    if request.post? and @person.update_attributes(params[:person])
      flash[:warning] = 'Person data successfully updated'
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
