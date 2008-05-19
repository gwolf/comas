# Methods added to this helper will be available to all templates in the application.
module ApplicationHelper
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
  # Show a translation-friendly pagination header (similar to WillPaginate's
  # page_entries_info - in fact, derived from it)
  def pagination_header(collection)
    if collection.page_count < 2
      case collection.size
      when 0; _("No items found")
      when 1; _("Displaying <b>1</b> items")
      else;   _("Displaying <b>all %d</b> items") % [collection.size]
      end
      else
      _('Displaying items <b>%d&nbsp;-&nbsp;%d</b> of <b>%d</b> in total') % 
        [ collection.offset + 1,
          collection.offset + collection.length,
          collection.total_entries ]
    end
  end

  ############################################################
  # Form builders
  class ComasFormBuilder < ActionView::Helpers::FormBuilder
    include GetText
    (field_helpers - %w(check_box radio_button select 
                        hidden_field)).each do |fldtype|
      src = <<-END_SRC
        def #{fldtype}(field, options={})
          title = options.delete(:title) || label_for_field(@object, field)
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
      column = @object.class.columns.select { |col| 
        col.name.to_s == field.to_s}.first

      if !column
        if @object.respond_to?(field) and 
            @object.connection.tables.include?(field) and
            model = field.camelcase.singularize.constantize
          # HABTM relation
          return checkbox_group(field, model.find(:all), options)
        else
          # Don't know how to handle this
          raise(NoMethodError,
                _('Field %s not defined for %s') % [field, @object.class])
        end
      end

      # Specially treated fields
      if field == 'id'
        return info_row(field, options)

      elsif field == 'passwd'
        options[:value] = ''
        return password_field(field, options)

      elsif field =~ /_id$/ and column.type == :integer and
          model = table_from_field(field)
        # field_id and there is a corresponding table? Present the catalog.
        choices = model.qualified_collection_by_id
        return select(field, 
                      choices.map {|it| [_(it[0]), it[1]]},
                      {:include_blank => true})
      end

      # Generic fields, based on data type
      case column.type.to_sym
      when :string
        return text_field(field, options) 

      when :text
        return text_area(field, options) 

      when :integer, :decimal, :float
        options[:class] ||= 'numeric'
        return text_field(field, options)

      when :boolean
        return radio_group(field, [[_('Yes'), true], [_('No'), false]], 
                           options)

      when :date, :time, :datetime
        return text_field(field, {:note => "Lazy bum, finish your code"})

      else
        # What is it, then? just report it...
        return info_row(field, options)

      end

    end

    def select(field, choices, options={})
      title = options.delete(:title) || label_for_field(@object, field)
      note = options.delete(:note)
      [before_elem(title,note), 
       super(field, choices ,options), 
       after_elem].join("\n")
    end

    def radio_group(field, choices, options={})
      title = options.delete(:title) || label_for_field(@object, field)
      note = options.delete(:note)
      [before_elem(title,note), 
       choices.map { |item|
         radio_button(field, item[1]) << ' ' << item[0]
       }, after_elem].join("\n")
    end

    def checkbox_group(field, choices, options={})
      title = options.delete(:title) || label_for_field(@object, field)
      note = options.delete(:note)

      fieldname = "#{@object_name}[#{field.singularize}_ids][]"

      [before_elem(title,note), 
       choices.map { |item|
         res = []
         res << '<span'
         res << "class=\"#{options[:class]}\"" if options[:class]
         res << '><input type="checkbox"'
         if @object.send(field.to_s.pluralize).include? item
           res << 'checked="checked"'
         end
         res << "id=\"#{fieldname}\" name=\"#{fieldname}\" value=\"#{item.id}\""
         res << "> #{_ item.name}</span><br/>"

         res.join(' ')
       }, after_elem].join("\n")
    end

    def info_row(field, options={})
      title = options[:title] || label_for_field(@object, field)
      note = options[:note]

      [ before_elem(title,note), 
        info_elem(@object.send(field)), 
        after_elem ].join("\n")
    end

    private
    def before_elem(title, note=nil)
      ['<div class="form-row">',
       %Q(<span class="comas-form-prompt">#{_ title}</span>),
       (note ? %Q(<span class="comas-form-note">#{_ note}</span>) : ''),
       '<span class="comas-form-input">'
      ].join("\n")
    end

    def after_elem
      '</span></div>'
    end

    def info_elem(info)
      %Q(<span class="comas-form-input">#{_ info.to_s}</span>)
    end

    def label_for_field(model, field)
      [model.class.to_s, field.to_s.humanize].join('|')
    end

    def table_from_field(field)
      return nil unless field =~ /_id$/
      tablename = field.gsub(/_id$/, '')
      return nil unless 
        ActiveRecord::Base.connection.tables.include? tablename.pluralize
      begin 
        model = tablename.camelcase.constantize
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
