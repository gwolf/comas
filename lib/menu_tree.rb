class MenuTree  < Array
  attr_accessor :menu_id, :entry_class, :elem_tag, :menu_tag

  def initialize *items
    options = ( ! items.empty? and 
                items[-1].is_a?(Hash) ) ? items.delete_at(-1) : {}

    self.concat items

    @menu_id = options.delete(:menu_id) || 'menu'
    @entry_class = options.delete(:entry_class) || 'menu-element'
    @menu_tag = options.delete(:menu_tag) || 'ul'
    @elem_tag = options.delete(:elem_tag) || 'li'

    options.empty? or raise(ArgumentError, 
                            _("Unexpected arguments received: ") <<
                            options.keys.sort.join(', '))
  end

  def to_s
    [menu_start, 
     self.map {|elem|  elem_start << elem.to_s << elem_end}.join("\n"),
     menu_end].join("\n")
  end

  def add(label, link=nil, tree=nil)
    mi = MenuItem.new(label, link, tree)
    self << mi
    mi
  end

  private
  def menu_start
    @menu_id ? %Q(<#{menu_tag} class="#{@menu_id}">) : "<#{menu_tag}>"
  end
  def menu_end; "</#{menu_tag}>";  end

  def elem_start
    @entry_class ? %Q(<#{elem_tag} class="#{@entry_class}">) : '<#{elem_tag}>'
  end
  def elem_end; "</#{elem_tag}>"; end
end

class MenuItem
  include ActionView::Helpers::UrlHelper

  attr_accessor :label, :link, :tree
  def self.set_base_url(url)
    @@base_url = url
  end

  def initialize(label, link=nil, tree=nil)
    @label = label.to_s
    @link = link
    @tree = tree
  end

  def to_s
    ret = build_link
    ret += @tree.to_s if @tree

    ret
  end

  private
  def build_link
    @label ||= ''
    return @label if @link.nil?
    return link_to(@label, link)
  end
end
