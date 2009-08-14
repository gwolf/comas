module ProposalsHelper
  ############################################################
  # For authors listings (incl. management)

  def authors_list_for_proposal(prop)
    prop.people.map do |p|
      '%s (%s)' % [link_to(h(p.name), :controller => 'people',
                           :action => 'profile', :id => p),
                   link_to(_('%d registered proposals') % p.proposals.size,
                           :controller => 'proposals', :action => 'by_author',
                           :author_id => p) ]
    end
  end

  # Receives a list of authorships (NOT people)
  def author_list_edition_table(auths)
    res=[table_tag, table_head_row_tag,
         [_('Position'), _('Name'), ''].map {|col| "<th>#{col}</th>"},
         end_table_row_tag]

    authpos = 0
    auths.each do |auth|
      res << table_row_tag <<
        table_col(link_author_up(auth), link_author_down(auth), authpos+=1) <<
        table_col(h auth.person.name) <<
        table_col(link_author_delete(auth)) <<
        end_table_row_tag
    end
    res << end_table_tag
    res.join("\n")
  end

  def link_author_delete(auth)
    if auth.proposal.authorships.size > 1
      confirm_msg = _('Are you sure you want to delete author' +
                      '"%s" from proposal "%s"? ') %
        [auth.person.name, auth.proposal.title]
    else
      confirm_msg = _('Removing the only registered author for this proposal ' +
                      'will also remove the proposal from the system. This ' +
                      'action cannot be undone. Are you sure you want to ' +
                      'continue?')
    end

    link_to( icon_trash,
             { :action => 'author_delete', :id => auth.proposal.id,
               :authorship_id => auth.id},
             { :method => 'post',
               :confirm => confirm_msg})
  end

  def link_author_up(auth)
    return icon_space if auth.first?
    link_to(icon_up, :action => 'author_up', :id => @proposal,
            :authorship_id => auth.id)
  end

  def link_author_down(auth)
    return icon_space if auth.last?
    link_to(icon_down, :action => 'author_down', :id => @proposal,
            :authorship_id => auth.id)
  end

  ############################################################
  # Documents display and handling

  # Produce the link to a document, accompanied by the relevant
  # information (description, size). The link will have a :filename
  # parameter, which will be ignored by us but might be meaningful to
  # the user.
  def link_to_document(doc, can_edit)
    delete_link = (can_edit ?
                   link_to(icon_trash, {:action => 'delete_document',
                             :id => @proposal, :document_id => doc},
                           :method => 'post',
                           :confirm => _('Are you sure you want to delete ' +
                                         'this document?')) :
                   '')
    _('%s %s: %s (%s)') % [delete_link,
                           link_to(h(doc.filename), :action => 'get_document',
                                   :id => @proposal, :document_id => doc.id,
                                   :filename => h(doc.filename)),
                           doc.descr, doc.human_size ]

  end
end
