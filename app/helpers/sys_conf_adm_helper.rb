module SysConfAdmHelper
  def attributes_table(attrs, modifiable=false)
    [ table_tag, attributes_head(modifiable),
      attrs.map {|a| attributes_row(a, modifiable)},
      end_table_tag ].join("\n")

  end

  def attributes_head(modifiable=false)
    columns = [_('Field name'), _('Field type')]
    columns << _('Null OK') << _('Default') << _('Action') if modifiable

    table_head_row_tag + columns.map {|col| "<th>#{col}</th>"}.join +
    end_table_row_tag
  end

  def attributes_row(attr, modifiable=false)
    columns = [attr.name, field_type_for(attr)]

    columns << (attr.null ? _('Yes') : _('No') ) <<
      attr.default <<
      [link_to(_('Delete'),
               { :action => 'delete_table_field',
                 :table => @table, :field => attr.name},
               { :method => 'post',
                 :confirm => _("Removing this field from the table " +
                               "definition will cause ALL OF ITS DATA to " +
                               "be destroyed. \n" +
                               "This is an irreversible action.\n" +
                               "Are you sure?")
               }),
       link_to(_('Edit'),
               :action => 'edit_table_field', :table => @table,
               :field => attr.name)
      ].join(' - ') if modifiable

    table_row_tag + columns.map {|col| "<td>#{col}</td>" }.join + end_table_row_tag
  end


  def field_type_for(field)
    type = field.type
    return type unless @types.include?(type)

    if type == :integer and field.name =~ /^(.*)_id$/
      begin
        ref_model = $1.pluralize.classify.constantize
        type = :catalog
      rescue NameError, NoMethodError
        # Don't panic, it is just... not a catalog. Go on.
      end
    end

    @types[type]
  end
end
