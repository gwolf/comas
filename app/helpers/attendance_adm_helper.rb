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
      item.time_to_start, item.tolerance_pre, item.tolerance_post,
      link_to(_('Choose'), :action => 'take', :id => item)].each do |col|
      ret << "<td>#{col}</td>" 
    end
    ret << '</tr>'

    ret
  end

  # Generates a human representation of the paper size (i.e. the name
  # followed by the dimensions in the user's prefered measuring unit)
  def human_paper_size(paper)
    '%s (%s)' % [paper, CertifFormat.paper_dimensions(paper)]
  end

  # Select field for paper size. Receives a FormBuilder object and the
  # field name.
  def paper_size_select(form, field)
    form.select(field, CertifFormat::PaperSizes.sort.map { |p| 
                  [human_paper_size(p), p] } )
  end

  # Select field for paper orientation. Receives a FormBuilder object
  # and the field name.
  def orientation_select(form,field)
    form.select field, CertifFormat::Orientations.map {|k, v| [_(v), k]}
  end

  def certif_format_line_header
    columns = [_('Vert'), _('Horiz'), _('Max width'), _('Content source'), 
               _('Content'), _('Font size'), _('Align'), '']
    ['<tr class="listing-head">',
     columns.map { |elem| '<th>%s</th>' % elem}, 
     '</tr>'].join("\n")
  end

  def certif_format_line_entry(line)
    columns = [line.human_y_pos, line.human_x_pos, line.human_max_width, 
               CertifFormatLine::ContentSources[line.content_source],
               line.content, line.font_size, line.justification,
               link_to(_('Delete'), 
                       {:action => 'delete_certif_format_line', 
                         :format_id => @format, :line_id => line},
                       {:confirm => _('Are you sure you want to delete ' +
                                      'this line?'),
                         :method => :post})
              ]

    [table_row_tag, 
     columns.map { |elem| '<td>%s</td>' % elem}, 
     end_table_row_tag].join("\n")
  end
end
