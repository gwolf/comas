module CertificatesAdmHelper
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
    columns = [_('Vert'), _('Horiz'), _('Max width'), _('Max height'),
               _('Content source'), _('Content'),
               _('Font size'), _('Align'), '']
    ['<tr class="listing-head">',
     columns.map { |elem| '<th>%s</th>' % elem},
     '</tr>'].join("\n")
  end

  def certif_format_line_entry(line)
    columns = [line.human_y_pos, line.human_x_pos, line.human_max_width,
               line.human_max_height,
               CertifFormatLine::ContentSources[line.content_source],
               line.content, line.font_size, line.justification,
               link_to(_('Delete'),
                       {:action => 'delete_line',
                         :id => @format, :line_id => line},
                       {:confirm => _('Are you sure you want to delete ' +
                                      'this line?'),
                         :method => :post})
              ]

    [table_row_tag,
     columns.map { |elem| '<td>%s</td>' % elem},
     end_table_row_tag].join("\n")
  end
end
