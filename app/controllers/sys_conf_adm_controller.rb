class SysConfAdmController < Admin
  before_filter :get_sysconf, :only => [:delete, :edit, :update]
  before_filter :get_table, :only => [:list_table_fields, :delete_table_field,
                                      :create_table_field, :edit_table_field]
  before_filter :field_types, :only => [:list_table_fields, :create_table_field,
                                        :edit_table_field]

  Menu = [[_('Show configuration'), :list],
          [_('Manage fields for registered people'), :list_people_fields]]

  ############################################################
  # Manage SysConf entries
  def list
    @confs = SysConf.find(:all, :order => :key)
    @new_conf = SysConf.new()
  end

  def delete
    redirect_to :action => :list
    return false unless request.post?
    @conf.destroy or
      flash[:error] = _('Error destroying requested entry: ') +
      @conf.errors.full_messages.join('<br/>')
  end

  def create
    redirect_to :action => :list
    return false unless request.post?
    conf = SysConf.new(params[:sys_conf])
    conf.save or flash[:error] = _('Error creating requested entry: ') +
      conf.errors.full_messages.join('<br/>')
  end

  def edit
  end

  def update
    redirect_to :action => :list
    return false unless request.post?

    if @conf.update_attributes(params[:sys_conf])
      flash[:notice] = _'The configuration entry was successfully updated'
    else 
      flash[:error] = _('Error updating requested configuration entry: ') +
        @conf.errors.full_messages.join("<br/>")
    end
  end

  ############################################################
  # Manage dynamic tables
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

      flash[:notice] = _("Successfully created %s field in %s") % 
        [field, @table]

    rescue TypeError, NameError, ActiveRecord::StatementInvalid => err
      flash[:error] = _('Unable to create requested column: %s') % err
    end
  end

  def delete_table_field
    redirect_to :action => :list_table_fields, :table => @table
    return true unless request.post?
    field = params[:field].to_sym

    if @model.extra_listable_attributes.select { |attr| 
        attr.name.to_sym == field }.empty?
      flash[:error] = _('Attempting to remove invalid field: %s') % field
      return false
    end

    begin
      @model.connection.remove_column(@table, field)
      flash[:notice] = _('Successfully removed field %s') % field
    rescue Exception => err
      flash[:error] = _('Error removing specified field: %s') % err
    end

    if field.to_s =~ /^(.*)_id$/ and 
        @model.connection.catalogs.include?($1.pluralize)
      flash[:warning] = _('Please note we have _not_ dropped the ' +
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
      flash[:error] = _'Invalid field specified'
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
      flash[:error] = _('Error setting the requested default value: %s') %
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
          flash[:error] = _("Error setting the field as not null: %s") % err
          return false
        end
      else
        # Sorry, not much we can do...
        flash[:error] = _('Cannot set field %s to reject null values: No ' +
                          'default value ') % name
        return false
      end
    end

    flash[:notice] = _("The field's values were correctly updated")
  end
  ############################################################
  protected
  def get_sysconf
    begin
      @conf = SysConf.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      flash[:error]= _('Invalid configuration entry %d requested')% params[:id]
      redirect_to :action => :list
      return false
    end
  end

  def get_table
    valid_tables = [:people]  # :proposals to be added later on..?

    begin
      @table = params[:table].to_sym
      raise NameError unless valid_tables.include? @table
      @model = @table.to_s.classify.constantize
    rescue NameError, NoMethodError
      flash[:error] = _'Invalid table requested'
      redirect_to '/'
      return false
   end
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
end
