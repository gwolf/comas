module ConferencesAdmHelper
  def row_for_attendee_listing(pers)
    res = []
    [pers.id, pers.firstname, pers.famname].each do |elem|
      if @user.has_admin_task?(:people_adm)
        res << link_to(h(elem), :controller => 'people_adm',
                       :action => 'show', :id => pers.id)
      else
        res << h(elem)
      end
    end

    [table_row_tag, res.map {|col| "<td>#{col}</td>"},
     end_table_row_tag].join("\n")
  end

  def row_for_timeslot_listing(tslot)
    res = [tslot.short_start_time, tslot.effective_tolerance_pre,
           tslot.effective_tolerance_post, tslot.attendances.size,
           tslot.room.name,
           link_to(_('Delete'),
                   { :action => 'destroy_timeslot',
                     :timeslot_id => tslot.id, :id => @conference.id },
                    {:confirm => _('Are you sure you want to permanently ' +
                                   'delete this timeslot? This will also ' +
                                   'destroy any attendances it has recorded'),
                     :method => :post} ) ]

    [table_row_tag, res.map {|col| "<td>#{col}</td>"}, end_table_row_tag].join("\n")
  end
end
