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

    res << _(pers.participation_in(@conference).participation_type.name)

    [table_row, res.map {|col| "<td>#{col}</td>"},
     end_table_row].join("\n")
  end
end
