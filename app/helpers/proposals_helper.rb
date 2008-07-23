module ProposalsHelper
  def authors_list_for_proposal(prop)
    prop.people.map do |p|
      link_to(_('%s (%d)') % [p.name, p.proposals.size],
              :controller => 'proposals', :action => 'by_author',
              :author_id => p)
    end
  end
end
