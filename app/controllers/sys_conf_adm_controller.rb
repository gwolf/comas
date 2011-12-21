class SysConfAdmController < Admin
  before_filter :get_sysconf, :only => [:delete, :edit, :update]
  before_filter :get_table, :only => [:list_table_fields, :delete_table_field,
                                      :create_table_field, :edit_table_field]
  before_filter :touch_dynamic_classes, :only => [:list_catalogs,
                                                  :show_catalog,
                                                  :delete_catalog_row,
                                                  :add_catalog_row]
  before_filter :get_catalog, :only => [:show_catalog, :delete_catalog_row,
                                        :add_catalog_row]
  before_filter :get_nametag_format, :only => [:nametag_format_edit,
                                               :nametag_format_delete,
                                               :nametag_format_up,
                                               :nametag_format_down]
  before_filter :field_types, :only => [:list_table_fields, :create_table_field,
                                        :edit_table_field]

  Menu = [[_('Configuration entries'), :list],
          [_('Catalogs management'), :list_catalogs],
          [_('Basic table fields handling'), nil,
           [ [_('Conferences'), :list_conferences_fields],
             [_('Proposals'), :list_proposals_fields],
             [_('People'), :list_people_fields]
           ]],
          [_('Printing format'), nil,
           [ [_('Nametags (EPL2)'), :nametag_format_list]]
          ]]

  ############################################################
  # SysConf entries management
  def list
    @confs = SysConf.find(:all, :order => :key)
    @new_conf = SysConf.new()
  end

  def delete
    redirect_to :action => :list
    return false unless request.post?
    @conf.destroy or
      flash[:error] << _('Error destroying requested entry: ') +
        @conf.errors.full_messages.join('<br/>')
  end

  def create
    redirect_to :action => :list
    return false unless request.post?
    conf = SysConf.new(params[:sys_conf])
    conf.save or flash[:error] << _('Error creating requested entry: ') +
      conf.errors.full_messages.join('<br/>')
  end

  def edit
  end

  def update
    redirect_to :action => :list
    return false unless request.post?

    if @conf.update_attributes(params[:sys_conf])
      flash[:notice] << _('The configuration entry was successfully updated')
    else
      flash[:error] << _('Error updating requested configuration entry: ') +
        @conf.errors.full_messages.join("<br/>")
    end
  end

  ############################################################
  # Dynamic tables management
  def list_table_fields
    @core = @model.core_attributes
    @extra = @model.extra_listable_attributes
  end

  def create_table_field
    redirect_to :action => :list_table_fields, :table => @table
    return true unless request.post?

    # Several things can go wrong when creating a column - In order
    # not to leave the DB in a state we don't want to, and to avoid
    # having the code too messed up with validations and if/elses,
    # just rescue it in case of failure.
    begin
      field = params[:fldname].downcase
      type = params[:fldtype].to_sym
      default = params[:flddefault]
      default = nil if default.blank?

      field =~ /^\w[\d\w\_]+$/ or raise NameError, _('Invalid column name')
      raise NameError, _('A field by that name is already defined') if
        @model.column_names.include?(field)
      raise TypeError, _('Invalid data type specified') unless
        @types.include?(type)

      if type == :catalog
        # A catalog is not a native type - fake it!
        catalog = field.pluralize
        ActiveRecord::Base.transaction do
          @model.connection.create_catalogs(catalog)
          @model.connection.add_reference(@table, catalog, :default => default)
        end
      else
        @model.connection.add_column(@table, field, type, :default => default)
      end

      notify_modified_structure _("Successfully created %s field in %s") %
        [field, @table]

    rescue TypeError, NameError, ActiveRecord::StatementInvalid => err
      flash[:error] << _('Unable to create requested column: %s') % err
    end
  end

  def delete_table_field
    redirect_to :action => :list_table_fields, :table => @table
    return true unless request.post?
    field = params[:field].to_sym

    if @model.extra_listable_attributes.select { |attr|
        attr.name.to_sym == field }.empty?
      flash[:error] << _('Attempting to remove invalid field: %s') % field
      return false
    end

    begin
      @model.connection.remove_column(@table, field)
      notify_modified_structure _('Successfully removed field %s') % field
    rescue Exception => err
      flash[:error] << _('Error removing specified field: %s') % err
    end

    if field.to_s =~ /^(.*)_id$/ and
        @model.connection.catalogs.include?($1.pluralize)
      flash[:warning] << _('Please note we have _not_ dropped the ' +
                           'corresponding catalog for this column, ' +
                           '<em>%s</em>, to avoid data loss. You can manually ' +
                           'remove it.') % $1.pluralize
    end
  end

  def edit_table_field
    fld = params[:field].to_sym
    begin
      @field = @model.extra_listable_attributes.select {|a|
        a.name.to_sym == fld }[0] or raise NameError
    rescue NameError
      redirect_to :action => 'list_table_fields', :table => @table
      flash[:error] << _('Invalid field specified')
      return false
    end
    return true unless request.post?

    name = @field.name
    default = params[:default]
    default = nil if default.blank?
    # Null handling can be a bit tricky, as setting it to false can
    # require updating all the null records (setting them to the
    # default)
    null = (params[:null_ok] == true)

    redirect_to :action => :list_table_fields, :table => @table
    begin
      @model.connection.change_column_default(@table, name, default)
    rescue ActiveRecord::StatementInvalid => err
      flash[:error] << _('Error setting the requested default value: %s') %
        err
      return false
    end

    if null
      # Granting permission to set it to null? Ok, just proceed...
      @model.connection.change_column_null(@table, name, true)
    elsif !@field.null
      # Is the field already rejecting null values? Good, then this is
      # a no-op!
    else
      if ! @field.default.blank?
        # Good, we have a default value - Set it wherever
        # needed. Anyway, this is prone to fail, so...
        begin
          @model.connection.select_all("UPDATE %s set %s = %s WHERE %s IS NULL"%
                                       [@table, name, @field.default,
                                        name])
          # And now, the magic!
          @model.connection.change_column_null(@table, name, false)
        rescue ActiveRecord::StatementInvalid => err
          flash[:error] << _("Error setting the field as not null: %s") % err
          return false
        end
      else
        # Sorry, not much we can do...
        flash[:error] << _('Cannot set field %s to reject null values: No ' +
                           'default value ') % name
        return false
      end
    end

    notify_modified_structure _("The field's values were correctly updated")
  end

  ############################################################
  # Catalogs management
  def list_catalogs
    @catalogs = ActiveRecord::Base.connection.catalogs.sort.map { |cat|
      begin
        model = cat.classify.constantize
      rescue NameError
        # Just ignore it
      end
    }.select {|cat| cat}
  end

  def show_catalog
    @data = @catalog.paginate(:page => params[:page], :order => 'id')
    @blank = @catalog.new
  end

  def delete_catalog_row
    redirect_to(:action => 'show_catalog', :catalog => @cat_name)
    return true unless request.post?
    begin
      @catalog.find(params[:id]).destroy
      flash[:notice] << _('The requested record was successfully deleted')
    rescue ActiveRecord::RecordNotFound
      flash[:error] << _('Requested record not found - '+
                         'Maybe it had already been deleted?')
    rescue  ActiveRecord::StatementInvalid
      flash[:error] << _('Error deleting the requested record - A catalog ' +
                         'entry will not be deleted if it is still referenced.')
    end
  end

  def add_catalog_row
    redirect_to(:action => 'show_catalog', :catalog => @cat_name)
    return true unless request.post?

    param_cat = @cat_name.singularize
    return true unless params.has_key?(param_cat)
    begin
      @catalog.new(:name => params[param_cat][:name]).save!
      flash[:notice] << _('The new %s was successfully registered') % param_cat
    rescue ActiveRecord::RecordInvalid => err
      flash[:error] << _('Could not create new %s: %s') %
        [param_cat, err.to_s]
    end
  end

  ############################################################
  # Nametag printing formats
  def nametag_format_list
    @formats = NametagFormat.find(:all, :order => :position)
  end

  def nametag_format_new
    @format = NametagFormat.new
    return unless request.post?
    if @format.update_attributes(params[:nametag_format])
      flash[:notice] << _('The requested format was successfully created')
      redirect_to :action => 'nametag_format_list'
    else
      flash[:error] << _('Error creating requested format: ') +
        @format.errors.full_messages.join("<br/>")
    end
  end

  def nametag_format_edit
    return unless request.post?
    if @format.update_attributes(params[:nametag_format])
      flash[:notice] << _('The requested format was successfully updated')
      redirect_to :action => 'nametag_format_list'
    else
      flash[:error] << _('Error updating requested format: ') +
        @format.errors.full_messages.join("<br/>")
    end
  end

  def nametag_format_delete
    @format.destroy
    flash[:notice] << _('The requested format was successfully deleted')
    redirect_to :action => 'nametag_format_list'
  end

  def nametag_format_up
    @format.move_higher
    redirect_to :action => 'nametag_format_list'
  end

  def nametag_format_down
    @format.move_lower
    redirect_to :action => 'nametag_format_list'
  end

  ############################################################
  protected
  def get_sysconf
    @conf = SysConf.find_by_key(params[:key])
    if @conf.nil?
      flash[:error] << _('Invalid configuration entry %d requested') %
        params[:id]
      redirect_to :action => :list
      return false
    end
  end

  def get_table
    valid_tables = [:people, :proposals, :conferences]

    begin
      @table = params[:table].to_sym
      raise NameError unless valid_tables.include? @table
      @model = @table.to_s.classify.constantize
      @model.reset_column_information
    rescue NameError, NoMethodError
      flash[:error] << _('Invalid table requested')
      redirect_to '/'
      return false
   end
  end

  def get_nametag_format
    begin
      @format = NametagFormat.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      flash[:error] << _('Invalid nametag format %d specified') % params[:id]
      redirect_to :action => 'nametag_format_list'
      return false
    end
  end

  def get_catalog
    begin
      cat = params[:catalog]

      ActiveRecord::Base.connection.catalogs.include?(cat) or
        raise NameError, _('Invalid catalog requested: %s') % cat

      model = cat.classify.constantize

    rescue NameError => err
      flash[:error] << err.to_s
      redirect_to :action => 'list_catalogs'
      return false
    end

    @cat_name = cat
    @catalog = model
  end

  def field_types
    @types = {
      :boolean => _('Boolean'),
      :date => _('Date'),
      :datetime => _('Timestamp'),
      :string => _('String'),
      :text => _('Text'),
      :integer => _('Integer'),
      :decimal => _('Decimal'),
      :float => _('Float'),
      :catalog => _('Catalog') # Not a real type, but hand-mangled by us
    }
  end

  def touch_dynamic_classes
    # Just "touch" the dynamic classes, to generate their MagicModels
    # to avoid catalogs not showing up due to NameErrors.
    Person
    Conference
    Proposal
  end

  def notify_modified_structure(msg)
    flash[:notice] << msg
    flash[:warning] << _('The database structure has been modified. ' +
                         'Typically, when running on a production ' +
                         'environment, you will want to restart Comas ' +
                         'to ensure no instances are left assuming the ' +
                         'previous state.')
  end
end
