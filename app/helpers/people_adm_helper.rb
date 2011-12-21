module PeopleAdmHelper
  def people_list_head
    res = []
    [[_('ID'), 'id'],
     [_('Login'), 'login'],
     [_('First name'), 'firstname'],
     [_('Family name'), 'famname'],
     [_('Last login at'), 'last_login_at'],
     ['',nil]
    ].each { |col|
      res << link_to(col[0], :sort_by => col[1],
                     :filter_by => @filter_by,
                     :conference_id => @conf ? @conf.id : nil)
    }

    join_for_row 'th', res
  end

  def list_row_for(person)
    res = []
    [:id, :login, :firstname, :famname].each do |col|
      res << link_to(h(person.send col), :action => :show, :id => person)
    end
    res << ( person.last_login_at.nil? ? '' :
             person.last_login_at.to_s(:listing) )
    res << link_to_if(@user != person, _('Delete'),
                      {:action => 'destroy', :id => person},
                      {:confirm => _("Are you sure you want to " +
                                     "permanently delete %s?") % person.name,
                        :method => :post})

    join_for_row 'td', res
  end

  def join_for_row(celltype, data)
    data.map {|col| "<%s>%s</%s>" % [celltype, col, celltype]}.join("\n")
  end

  def xls_list_link(order, filter, conf)
    params = {}
    params[:order_by] = order unless order.nil? or order.blank?
    params[:filter_by] = filter unless filter.nil? or filter.blank?
    params[:conference_id] = conf.id unless conf.nil?
    params[:xls_output] = true

    link_to(_('Download this listing'), params)
  end
end
