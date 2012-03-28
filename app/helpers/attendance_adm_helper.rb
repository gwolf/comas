module AttendanceAdmHelper
  def tslot_table(tslots)
    classes = list_row_classes
    row = 0

    ret = '<table class="timeslot-list">'
    ret << tslot_head
    tslots.each do |item|
      row += 1
      rowclass = classes[row % classes.size]
      ret << tslot_row(rowclass, item)
    end
    ret << '</table>'
  end

  def tslot_head
    ret = '<tr class="listing-head">'
    [_('Conference'), _('Room'), _('Start time'), _('Time distance'),
      _('Tolerance (pre)'),_('Tolerance (post)'), ''].each do |col|
      ret << "<th>#{col}</th>"
    end
    ret << '</tr>'

    ret
  end

  def tslot_row(rowclass, item)
    ret = "<tr class=\"#{rowclass}\">"
    [ item.conference.name, item.room.name, item.short_start_time,
      time_ago_in_words(item.start_time), item.tolerance_pre, item.tolerance_post,
      link_to(_('Choose'), :action => 'take', :id => item)].each do |col|
      ret << "<td>#{col}</td>"
    end
    ret << '</tr>'

    ret
  end
end
