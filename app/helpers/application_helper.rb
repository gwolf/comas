# -*- coding: utf-8 -*-
# Methods added to this helper will be available to all templates in the application.
module ApplicationHelper
  ######################################################################
  # Layout-related elements
  def show_flash
    flash.map do |level, message|
      message = message.join("<br/>") if message.is_a? Array
      next if message.blank?
      flash.discard(level)
      '<div id="flash-%s">%s</div>' % [level, message]
    end
  end

  def login_data
    return '' unless @user
    '<div id="logindata">%s (%s) - %s</div>%s' %
      [h(@user.login), h(@user.name),
       link_to(_('Log out'), {:controller => '/people',
         :action => 'logout'}),
       my_photo]
  end

  def my_photo
    return '' unless @user and @user.has_photo?
    ratio = Photo.thumb_ratio
    photo = @user.photo
    '<div id="myphoto"><img src="%s" width="%d" height="%d" /></div>'%
        [ photo.url_thumb, @user.photo.width * ratio, @user.photo.height * ratio]
  end

  def rss_links
    return '' unless @rss_links.is_a? Hash
    @rss_links.keys.map { |source|
      ( '<link rel="alternate" type="application/rss+xml" ' +
        'title="%s" href="%s" />' ) %
      [source, @rss_links[source]]
    }.join("\n")
  end

  ######################################################################
  # Icon buttons and similar stuff
  def icon_up
    image_tag 'up.png', :border => 0, :alt => _('Up'), :size => '16x16'
  end

  def icon_down
    image_tag 'down.png', :border => 0, :alt => _('Down'), :size => '16x16'
  end

  def icon_space
    image_tag 'space.png', :border => 0, :alt => _('-'), :size => '16x16'
  end

  def icon_trash
    image_tag 'trash.png', :border => 0, :alt => _('-'), :size => '16x16'
  end

  # This function disappeared from gettext_rails ~2.1 - Reintroduce it
  # (a bit simplified) here...
  def available_locales
    (Dir.glob(File.join(RAILS_ROOT, 'locale/[a-z]*')).map { |path|
       File.basename(path)} << 'en').uniq.sort
  end

  def locale_links
    available_locales.map { |loc|
      lang = Translation.for(Language.for_locale(loc).qualified_name)
      '[%s]' % link_to_unless(GetText.locale.to_s == loc, lang, :lang => loc)
    }.join(' ')
  end

  def link_to_proposal(prop)
    return '' unless prop.is_a? Proposal
    link_to(prop.title, :controller => 'proposals',
            :action => 'show', :id => prop)
  end

  def link_to_login_or_new
    return '' if @user
    '<div class="please-register">' <<
      (_('Please %s or %s if you are interested in attending') %
       [ link_to(_('register'), :controller => '/people',
                 :action => 'new'),
         link_to(_('log in'), :controller => '/people',
                 :action => 'login') ]) << '</div>'
  end

  ######################################################################
  # RedCloth formatting help
  def redcloth_help
    render :partial => 'inc/redcloth_help'
  end

  ######################################################################
  # Collapsible areas with a title header
  #
  # This function can be called either with explicitly given data or
  # with a block from your view. This means, both following usages will work:
  #
  # <% collapsed_header 'Description' do %>
  #   <%= @conference.descr %>
  # <% end %>
  #
  # and
  #
  # <%= collapsed_header 'Description', @conference.descr %>
  #
  # Why? As a matter of taste, and in order not to break the places it
  # is already used (and to add extra flexibility, allowing for
  # cleaner inlined code blocks). Even both can be specified:
  #
  # <% collapsed_header 'Description', 'Conference description follows:' do %>
  #   <p><%= @conference.descr %></p>
  #   <p>…Which is <%= @conference.descr.size %> characters long</p>
  # <% end %>
  def collapsed_header(title, data='', &block)
    # Not collision-proof, right. However, odds are quite low!
    div_name = 'comas-collapsed-%d' % (rand * 10000)

    pre = '<h3>%s - <span class="note">%s</span></h3>
           <div id="%s" class="comas-collapsed" style="display: none">' %
      [ title,
        link_to_function(_('Show'), visual_effect(:toggle_blind, div_name)),
        div_name ]
    post = '</div>'

    if block
      concat pre
      concat data
      yield
      concat post
    else
      pre << data << post
    end
  end

  ######################################################################
  # Listing tables (alternating background colors)
  def list_row_classes
    ['listing-even', 'listing-odd']
  end

  def table(&block)
    @table_rows = 0
    concat '<table>'
    yield
    concat '</table>'
  end

  def table_tag; @table_rows=0; '<table>'; end
  def end_table_tag; '</table>'; end

  def table_head_row (&block)
    concat '<tr class="listing-head">'
    yield
    concat '</tr>'
  end

  def table_head_row_tag; '<tr class="listing-head">'; end

  def table_head_row_for(*items)
    [table_head_row, items.map {|it| "<th>#{it}</th>"}, '</tr>'].join("\n")
  end

  def table_row_tag
    @table_rows += 1
    "<tr class=\"#{list_row_classes[@table_rows % list_row_classes.size]}\">"
  end

  def end_table_row_tag; '</tr>'; end

  def table_row(&block)
    @table_rows += 1
    concat('<tr class="%s">' %
           list_row_classes[@table_rows % list_row_classes.size])
    yield
    concat '</tr>'
  end

  def table_col(*items)
    "<td>#{items.join("\n")}</td>"
  end

  ############################################################
  # Regular information elements
  def info_row(title, data)
    %Q(<div class="info-row">
         <span class="info-title">#{title}</span>
         <span class="info-data">#{h data}</span>
       </div>)
  end

  def redcloth_info_row(title, data)
    %Q(<div class="info-row">
         <span class="info-title">#{title}</span>
         <span class="info-data">#{RedCloth.new(data).to_html}</span>
       </div>)
  end

  def auto_info_row_for(object, column)
    begin
      attr = column.name
      fldname = Translation.for(attr.to_s.humanize)
      type = column.type
      value = object.send(attr) || ''

      # Text fields should be formatted with RedCloth and shown collapsed.
      # And the empty string: So that we do not repeat the attribute name
      if type == :text
        return collapsed_header(Translation.for(fldname),
                                redcloth_info_row('', value))
      end

      # Catalog fields should show the referred entry
      if attr =~ /_id$/
        return '' if value == ''
        klass = attr.gsub(/_id$/,'').classify.constantize
        return info_row(fldname, klass.find_by_id(value).name)
      end

      # Everything else should show itself :)
      return info_row(fldname, value)
    rescue NameError
      # Looks like a catalog reference, but is not
      return info_row(fldname, value)
    rescue NoMethodError
      # This is just guesswork... If any NoMethodError is raised, just
      # return nil and go on with it.
      return nil
    end
  end

  ############################################################
  # From rows (for regular layout, whether we use ComasFormBuilder or not)
  def form_row(title, input, note=nil)
    res = ['<div class="form-row">',
           '<span class="comas-form-prompt">%s</span>' % title]
    res << '<span class="comas-form-note">%s</span>' % note if note
    res << '<span class="comas-form-input">%s</span>' % input
    res << '</div>'

    res.join("\n")
  end

  ############################################################
  # Show a translation-friendly pagination header (similar to WillPaginate's
  # page_entries_info - in fact, derived from it)
  def pagination_header(collection)
    ['<div class="pagination">',
     if collection.total_pages < 2
       case collection.size
       when 0; _("No items found")
       when 1; _("Displaying <b>1</b> item")
       else;   _("Displaying <b>all %d</b> items") % [collection.size]
       end
     else
       _('Displaying items <b>%d&ndash;%d</b> of <b>%d</b> in total') %
         [ collection.offset + 1,
           collection.offset + collection.length,
           collection.total_entries ]
     end,
     '</div>' ].join ''
  end

  ############################################################
  # Form builders
  class ComasFormBuilder < ActionView::Helpers::FormBuilder
    include GetText
    include ActionView::Helpers::DateHelper

    (%w(date_field) +
     field_helpers - %w(check_box radio_button select
                        hidden_field)).each do |fldtype|
      src = <<-END_SRC
        def #{fldtype}(field, options={})
          title = options.delete(:title) || label_for_field(@object, field)
          note = options.delete(:note)

          options[:size] ||= 60 if '#{fldtype}' == 'text_field'

          with_format(title, super(field, options), note)
        end
      END_SRC
      class_eval src, __FILE__, __LINE__
    end

    def auto_field(field, options={})
return nil if @object.nil?
      column = @object.class.columns.select { |col|
        col.name.to_s == field.to_s}.first

      # To check for specially treated fields, we need the field to be
      # a string (not a symbol, as it is usually specified)
      field = field.to_s

      if !column
        if @object.respond_to?(field) and
            @object.connection.tables.include?(field) and
            model = field.camelcase.singularize.constantize
          # HABTM relation
          options[:order_by] ||= :name
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
                      choices.map {|it| [Translation.for(it[0]), it[1]]},
                      {:include_blank => true})
      end

      # Generic fields, based on data type
      case column.type.to_sym
      when :string
        return text_field(field, options)

      when :text
        options[:size] ||= '70x15'
        return text_area(field, options)

      when :integer, :decimal, :float
        options[:class] ||= 'numeric'
        return text_field(field, options)

      when :boolean
        return radio_group(field, [[_('Yes'), true], [_('No'), false]],
                           options)

      when :date
        return date_field(field, options)

      when :datetime
        return datetime_select(field, options)

      else
        # What is it, then? just report it...
        return info_row(field, options)

      end

    end

    def datetime_select(field, options={})
      title = options.delete(:title) || label_for_field(@object, field)
      note = options.delete(:note)
      options[:default] = @object.send(field)
      with_format(title, super(@object_name, field,
                               {:default=>@object.send(field)}.merge(options)),
                  note)
    end

    def select(field, choices, options={})
      title = options.delete(:title) || label_for_field(@object, field)
      note = options.delete(:note)
      with_format(title, super(field, choices, options), note)
    end

    def radio_group(field, choices, options={})
      title = options.delete(:title) || label_for_field(@object, field)
      note = options.delete(:note)
      with_format(title, choices.map { |item|
                    radio_button(field, item[1]) << ' ' << item[0] }.to_s,
                  note)
    end

    def checkbox_group(field, choices, options={})
      title = options.delete(:title) || label_for_field(@object, field)
      note = options.delete(:note)
      options[:order_by] ||= :id

      fieldname = "#{@object_name}[#{field.singularize}_ids][]"

      with_format(title,
                  choices.sort_by(&options[:order_by]).map { |item|
                    res = []
                    res << '<span'
                    res << "class=\"#{options[:class]}\"" if options[:class]
                    res << '><input type="checkbox"'
                    if @object.send(field.to_s.pluralize).include? item
                      res << 'checked="checked"'
                    end
                    res << "id=\"#{fieldname}\" name=\"#{fieldname}\" "
                    res << "value=\"#{item.id}\"> #{_ item.name}</span><br/>"

                    res.join(' ') }.to_s,
                  note)
    end

    def info_row(field, options={})
      title = options[:title] || label_for_field(@object, field)
      note = options[:note]

      with_format(title, info_elem(@object.send(field)), note)
    end

    def manual_in_row(content, options={})
      title = options[:title]
      note = options[:note]
      with_format(title, content, note)
    end

    private
    def with_format(title, body, note=nil)
      # Ugh... Straight copied from form_row above. How to call
      # this function from this very same module!?
      res = ['<div class="form-row">',
             '<span class="comas-form-prompt">%s</span>' % _(title)]
      res << '<span class="comas-form-note">%s</span>' % _(note) if note
      res << '<span class="comas-form-input">%s</span>' % body
      res << '</div>'

      res.join("\n")
    end

    def info_elem(info)
      %Q(<span class="comas-form-input">#{_ info.to_s}</span>)
    end

    def label_for_field(model, field)
      Translation.for([model.class.to_s, field.to_s.humanize].join('|'))
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
