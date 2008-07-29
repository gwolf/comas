module ProposalsHelper
  def authors_list_for_proposal(prop)
    prop.people.map do |p|
      link_to(_('%s (%d)') % [p.name, p.proposals.size],
              :controller => 'proposals', :action => 'by_author',
              :author_id => p)
    end
  end

  # Receives a list of authorships (NOT people)
  def author_list_edition_table(auths)
    res=[start_table, table_head_row,
         [_('Position'), _('Name'), ''].map {|col| "<th>#{col}</th>"},
         end_table_row]

    authpos = 0
    auths.each do |auth|
      res << table_row << 
        table_col(link_author_up(auth), link_author_down(auth), authpos+=1) << 
        table_col(auth.person.name) <<
        table_col(link_author_delete(auth)) <<
        end_table_row
    end
    res << end_table
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
end
