# Methods added to this helper will be available to all templates in the application.
module ApplicationHelper
  ######################################################################
  # Main menu
  def render_menu tree=@menu
    return '' unless tree.is_a? Array

    [ '<ul>',
      tree.map {|item| '<li>' << menu_item(item) << '</li>'}, 
      '</ul>' ].join("\n")
  end

  def menu_item item
    return '' unless item.is_a? Hash and item.include? :label
    ret = ''
    if item.include? :link
      ret << link_to(item[:label], item[:link])
    else
      ret << item[:label]
    end
    ret << render_menu(item[:children]) if item.has_key?(:children)

    ret
  end


  ######################################################################
  # Listing tables (alternating background colors
  def list_row_classes
    ['listing-even', 'listing-odd']
  end

  def start_table
    @table_rows = 0
    '<table>'
  end

  def end_table; '</table>'; end
  def table_head_row; '<tr class="listing-head">'; end

  def table_row
    @table_rows += 1
    "<tr class=\"#{list_row_classes[@table_rows % list_row_classes.size]}\">"
  end

  def end_table_row; '</tr>'; end

end
