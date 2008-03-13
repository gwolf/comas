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
  # Listing tables (alternating background colors)
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

  ############################################################
  # Form builders
  class ComasFormBuilder < ActionView::Helpers::FormBuilder
    (field_helpers - %w(check_box radio_button select 
                        hidden_field)).each do |fldtype|
      src = <<-END_SRC
        def #{fldtype}(field, options={})
          title = options.delete(:title) || field.to_s.humanize
          note = options.delete(:note)

          options[:size] ||= 60 if '#{fldtype}' == 'text_field'

          [before_elem(title, note), 
           super(field,options), 
           after_elem].join("\n")
        end
      END_SRC
      class_eval src, __FILE__, __LINE__
    end

    def auto_field(field, options={})
      column = @object.class.columns.select {|col| col.name == field}.first
      raise(NoMethodError, 
            "Field #{field} not defined for #{@object.class}") if column.nil?

      if column.text?
        return text_field(field, options) 
      elsif column.number?
        if field =~ /_id$/ and model = table_from_field(field)
          return select(field, model.find(:all).sort {|a,b| a.name <=> b.name}.
                        collect {|item| [item.name, item.id]},
                        {:include_blank => true})
        else
          options[:size] ||= 10
          return text_field(field, options)
        end
      else

      end

    end

    def select(field, choices, options={})
      title = options.delete(:title) || field.to_s.humanize
      note = options.delete(:note)
      [before_elem(title,note), 
       super(field, choices ,options), 
       after_elem].join("\n")
    end

    def info_row(field, options={})
      title = options[:title] || ''
      note = options[:note]

      [ before_elem(title,note), 
        info_elem(@object.send(field)), 
        after_elem ].join("\n")
    end

    private
    def before_elem(title, note=nil)
      ['<div class="form-row">',
       %Q(<span class="comas-form-prompt">#{title}</span>),
       (note ? %Q(<span class="comas-form-note">#{note}</span>) : ''),
      '<span class="comas-form-input">'
      ].join("\n")
    end

    def after_elem
      '</span></div>'
    end

    def info_elem(info)
      %Q(<span class="comas-form-input">#{info}</span>)
    end

    def table_from_field(field)
      return nil unless field =~ /_id$/
      tablename = field.gsub(/_id$/, '')
      return nil unless 
        ActiveRecord::Base.connection.tables.include? tablename.pluralize
      begin 
        model = eval(tablename.camelcase)
      rescue
        return nil
      end

      model
    end
  end

  def comas_form_for(name, object=nil, options=nil, &proc)
    form_for(name, object,
             (options||{}).merge(:builder => ComasFormBuilder), &proc)
  end

end
