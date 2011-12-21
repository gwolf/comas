# -*- coding: utf-8 -*-
class PeopleAdmController < Admin
  before_filter :get_person, :only => [:show, :destroy]

  Menu = [[_('Registered people list'), :list],
          [_('Administrative tasks'), :by_task],
          [_('Massive mailing'), :mass_mail],
          [_('Statistical graphs'), :graph_list]]

  ############################################################
  # Generic CRUD functions for people
  def index
    redirect_to :action => 'list'
  end

  def list
    @order_by = 'people.' + sort_for_fields(['id', 'login', 'firstname',
                                         'famname', 'last_login_at'])
    @filter_by = params[:filter_by]
    @conferences = Conference.find(:all).sort_by(&:begins)
    if params[:conference_id].blank?
      people = Person.name_find(@filter_by, :order => @order_by)
    else
      @conf = Conference.find(params[:conference_id])
      people = @conf.people.name_find(@filter_by, :order => @order_by)
    end

    if params[:xls_output]
      columns = Person.flattributes_for_list - %w(pw_salt passwd)
      xls = SimpleXLS.new
      xls.add_header(columns)

      people.each do |pers|
        # We might be calling somecatalog_name - So we'd better rescue
        # to nil.
        xls.add_row( columns.map {|col| pers.send(col) rescue nil } )
      end

      send_data(xls.to_s, :type => 'application/vnd.ms-excel',
                :filename => 'list.xls')
    else
      @people = people.paginate(:page => params[:page])
    end
  end

  def new
    @person = Person.new
  end

  def create
    person_data = params[:person]
    conferences = person_data.delete(:conference_ids)

    @person = Person.new(params[:person])
    if @person.save
      flash[:notice] << _('New attendee successfully registered')
      if conferences and !conferences.empty?
        @person.conference_ids = conferences
        flash[:notice] << _('Requested conferences registered')
      end
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

  def mailable_list
    recipients = Person.mailable
    if params[:mode] == 'full'
      text = recipients.map {|rcpt| rcpt.name_and_email}
    else
      text = recipients.map {|rcpt| rcpt.email}
    end

    send_data(text.uniq.sort.join("\n"),
              :type => 'text/plain',
              :disposition => 'attachment',
              :filename => 'mailable_list.txt')
  end

  def graph_list
    @graphs =  Person.column_names.select {|cn| cn =~ /_id$/}.
      map {|cn| cn.gsub(/_id$/, '')}.
      select {|c| c.singularize.classify.constantize.is_catalog?}
    types = graph_types
    @types = types.keys.sort
  end

  def get_graph
    type = params[:graph_type]
    table = params[:table]
    sort = params[:sort]
    data = data_for_graph(table) or return false

    graphtype = graph_types[type] || Gruff::Bar
    gruff = graphtype.new('1024x768')
    gruff.minimum_value = 0 if gruff.class == Gruff::Line

    gruff.title = _('Distribution by %s for all registered people') % table
    col=0
    gruff.marker_font_size = 15

    if graphtype == Gruff::Pie
      data.keys.sort.each do |id|
        num=0 if num.nil?
        gruff.data(data[id][:label], [data[id][:value]])
      end
    else
      gruff.hide_legend=true
      values = []
      data.keys.sort_by {|id| sort == 'value' ? 1-data[id][:value] : id}.
        each do |id|
        gruff.labels[gruff.labels.size] = data[id][:label][0..20]
        values[values.size] = data[id][:value]
      end
      gruff.data('', values)
    end

    warn gruff.labels.to_yaml
    send_data(gruff.to_blob('png'),
              :type => 'image/png',
              :disposition => 'inline')
  end

  private
  def graph_types
    return {
      'accumulator' => Gruff::AccumulatorBar,
      'area' => Gruff::Area,
      'bar' => Gruff::Bar,
      'dot' => Gruff::Dot,
      'net' => Gruff::Net,
      'pie' => Gruff::Pie,
      'side_bar' => Gruff::SideBar,
      'stacked_area' => Gruff::StackedArea,
      'stacked_bar' => Gruff::StackedBar
    }
  end

  def data_for_graph(table)
    begin
      model = table.singularize.classify.constantize
      unless Person.column_names.include?('%s_id' % table) and
          model.is_catalog?
        raise NameError, _('Invalid related table specified: %s' % table)
      end
    rescue NameError => err
      flash[:error] << err.message
      redirect_to :action => :graph_list
      return false
    end

    res = {}
    model.all.map {|item| res[item.id] = {:label => item.name, :value => item.people.size}}

    return res
  end

  def get_person
    return true if params[:id] and @person = Person.find_by_id(params[:id])
    redirect_to :action => :list
  end
end
