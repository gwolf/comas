class PeopleAdmController < Admin
  before_filter :get_person, :only => [:show, :destroy]

  Menu = [[_('Registered people list'), :list],
          [_('Administrative tasks'), :by_task],
          [_('Massive mailing'), :mass_mail]]

  ############################################################
  # Generic CRUD functions for people
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

  def new
    @person = Person.new
  end

  def create
    @person = Person.new(params[:person])
    if @person.save
      flash[:notice] << _('New attendee successfully registered')
      redirect_to :action => 'list'
    else
      flash[:error] << [_("Error registering requested attendee: "),
                        @person.errors.full_messages ]
      render :action => 'new'
    end
  end

  def show
    return true unless request.post? 
    begin
      @person.transaction do
        # Split the HABTM-tasks into each of their components, so in
        # case one of the associations fail, the request continues to
        # be carried out (and chicken out only if it is on an
        # unforseen situation)
        conference_ids = params[:person].delete(:conference_ids) || []

        @person.update_attributes(params[:person])

        # Conferences: The cleanest thing I could come up with is to
        # go over the complete list of conferences, one by one. Just
        # assigning the conference_ids hash to person#conference_ids
        # raises an exception upon the first mishap, and we want to
        # continue.
        Conference.find(:all, :order => 'id').each do |conf|
          present = @person.conferences.include?(conf)
          desired = conference_ids.include?(conf.id.to_s)
          next if present == desired

          begin
            if desired
              @person.conferences += [conf] 
            else 
              @person.conferences -= [conf]
            end
          rescue ActiveRecord::RecordNotSaved => err
            flash[:warning] << err.message
          end
        end

        # Admin tasks - Just ensure you are not removing people_adm
        # privileges from yourself
        this_task = AdminTask.find_by_sys_name('people_adm')
        if @person == @user  and !@person.admin_tasks.include? this_task
          flash[:notice] << _('Removing this administrative task from your ' +
                              'own account is not allowed - Restoring.')
          @person.admin_tasks << this_task 
        end

        flash[:notice] << _('Person data successfully updated')
      end
   rescue TypeError => err
     flash[:error] << _("Error recording requested data: %s") % err
    end
  end

  def destroy
    if request.post? 
      if @person != @user and @person.destroy
        flash[:notice] << _('Successfully removed requested attendee')
      else
        flash[:error] << [_('Error removing requested attendee: '),
                          @person.errors.full_messages]
      end
    else
      flash[:error] << _('Invocation error')
    end

    redirect_to :action => 'list'
  end

  ############################################################
  # List of all people with administrative privileges
  def by_task
    @tasks = AdminTask.find(:all, :include => :people)
  end

  ############################################################
  # Mass-mailing
  def mass_mail
    @recipients = Person.mailable
    return true unless request.post?
    if params[:title].nil? or params[:title].empty? or 
        params[:body].nil? or params[:body].empty?
      flash[:error] << _('You must specify both email title and body')
      return false
    end

    @recipients.each do |rcpt|
      begin
        Notification.deliver_admin_mail(@user, rcpt, 
                                        params[:title], params[:body])
      rescue Notification::InvalidEmail
        flash[:warning] << _('User %s (ID: %s) is registered with an ' +
                              'invalid email address (%s). Skipping...') %
          [rcpt.name, rcpt.id, rcpt.email]
      end
    end

    flash[:notice] << _('The %d requested mails have been sent.') % 
      @recipients.size
    redirect_to :action => 'list'
  end

  private
  def get_person
    return true if params[:id] and @person = Person.find_by_id(params[:id])
    redirect_to :action => :list
  end
end
