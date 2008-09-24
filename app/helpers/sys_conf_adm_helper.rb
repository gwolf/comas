module SysConfAdmHelper
  def attributes_table(attrs, modifiable=false)
    [ start_table, attributes_head(modifiable), 
      attrs.map {|a| attributes_row(a, modifiable)},
      end_table ].join("\n")
    
  end

  def attributes_head(modifiable=false)
    columns = [_('Field name'), _('Field type')]
    columns << _('Null OK') << _('Default') << _('Action') if modifiable

    table_head_row + columns.map {|col| "<th>#{col}</th>"}.join + end_table_row
  end

  def attributes_row(attr, modifiable=false)
    columns = [attr.name, 
               (@types[attr.type] || attr.type)]

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

    table_row + columns.map {|col| "<td>#{col}</td>" }.join + end_table_row
  end
end
