# -*- coding: utf-8 -*-
# = Nametags printing
#
# This application presents a user-friendly interface for generating
# the nametag labels using a suitable (EPL2) label printer, such as
# the pretty ubiquuous Zebra printers.
#
# === Configuration
#
# Some aspects of this application can be specified via environment variables:
#
# * GETTEXT_PATH - The path for the GetText translation files (in case
#   you want an interface language other than English). Defaults to 'locale'.
# * LANG - Your locale (language) specification. English interface will be 
#   shown if this variable is not specified (or no suitable translation 
#   exists)
# * NAMETAG_PRINTER - The port where the printer is connected, or the file 
#   where the output should be sent to. Defaults to /dev/lp0.
# * NAMETAG_CHARSET - The character set this printer supports. Zebra printers 
#   support 8-bit charsets only, which means we will have to translate via
#   Iconv. Defaults to CP850 (EPL2 printers' default). Note that if an invalid
#   encoding is requested, the strings will be sent to the printer as they are 
#   (i.e. in UTF8), resulting in garbled results whenever they are not 7-bit 
#   clean.

require 'libglade2'
require 'singleton'

# The class responsible for starting up the aplication
class NametagApp
  def initialize
    app = NametagsGlade.new('lib/nametags/nametags.glade')
    app.show

    Gtk.main
  end
end

# Application window controller, based on Glade's generated template
class NametagsGlade
  include GetText
  bindtextdomain("comas", ENV['GETTEXT_PATH'])
  attr :glade

  def initialize(path_or_data, root = nil, domain = 'comas', 
                 localedir = 'locale', flag = GladeXML::FILE)
    bindtextdomain(domain, localedir, nil, "UTF-8")

    @glade = GladeXML.new(path_or_data, root, domain, 
                          localedir, flag) {|handler| method(handler)}

    begin
      setup_conferences_list(@glade["conference_combobox"])
      setup_people_list(@glade["peoplelist_treeview"])
      setup_formats_list(@glade["format_combobox"])
    rescue PGError
      @err_dialog = @glade['conn_error_dialog']
      @err_dialog.show_all
      @err_dialog.signal_connect("destroy") { Gtk.main_quit }
      Gtk.main
      exit 1
    end
  end

  # Show the main window
  def show
    @window = @glade['window1']
    @window.show_all
    @window.signal_connect("destroy") { Gtk.main_quit }
  end

  ############################################################
  # Callbacks

  def on_conference_combobox_changed(combo)
    populate_people(@glade['peoplelist_treeview'].model, combo.active_iter[1])    
  end

  def on_format_combobox_changed(combo)
    @format_id = combo.active_iter[1] unless combo.active_iter.nil?
  end

  def on_quit_button_clicked(button)
    Gtk.main_quit
  end

  def on_peoplelist_treeview_row_activated(view, path, column)
    return unless iter = view.model.get_iter(path)
    print_label_for(@people[iter[0]])
  end

  def on_print_button_clicked(button)
    return unless iter = @glade["peoplelist_treeview"].selection.selected
    print_label_for(@people[iter[0]])
  end

  def on_refresh_button_clicked(button)
    confs = @glade['conference_combobox']
    people = @glade['peoplelist_treeview']

    # Select the first iterator if needed - Things will break horribly
    # otherwise (i.e. the program dies :-/ )
    confs.active_iter ||= confs.model.iter_first

    populate_people(people.model, confs.active_iter[1])
  end

  def on_conn_error_dialog_button_clicked(button)
    Gtk.main_quit
  end

  ############################################################
  private
  # Creates the main people listing's MVC structure
  def setup_people_list(treeview)
    model = Gtk::ListStore.new(Integer, String, String, String, Person)
    treeview.model = model

    colnum = 0
    [_('ID'), _('First name'), _('Family name'), _('Login')].each do |title|
      col = Gtk::TreeViewColumn.new(title, 
                                    Gtk::CellRendererText.new,
                                    'text' => colnum)
      col.clickable = true
      col.resizable = true
      col.sort_column_id = colnum
      treeview.append_column(col)
      colnum += 1
    end

    treeview.enable_search = true
    treeview.search_column = 2

    populate_people(model)
  end

  # Populates the main listing, showing all the people for the
  # currently selected conference (or for all conferences, if none is
  # selected).
  #
  # This function will be called each time the list must be
  # repopulated.
  def populate_people(model, conf_id = 0)
    model.clear
    if conf_id > 0
      begin
        conf = Conference.find(conf_id, :include => 'people')
        people_list_from conf.people
      rescue
        # Any problems? Update the conferences (maybe a conference was
        # deleted since we were invoked?) listing and return the full people
        # list.
        populate_conferences_list(@glade["conference_combobox"].model)
        populate_people(model)
        return true
      end
    else
      people_list_from Person.find(:all)
    end

    @people.values.each do |pers|
      iter = model.append
      iter[0] = pers.id
      iter[1] = pers.firstname
      iter[2] = pers.famname
      iter[3] = pers.login
    end
    set_status _("Displaying %d people") % @people.size
  end

  # Creates a hash (indexed by ID) from a list of people
  def people_list_from(collection)
    @people = {}
    collection.each {|pers| @people[pers.id] = pers}
  end

  # Creates the needed MVC infrastructure for the conferences combobox
  def setup_conferences_list(combo)
    model = setup_combobox(combo)
    populate_conferences_list(model)
  end

  # Populates the conferences listing combobox
  def populate_conferences_list(model)
    model.clear # Just in case we are being refreshed
    model.append # Add and activate an empty line to begin with
    Conference.find(:all, :include => :people).sort_by {|c| 
      c.distance_to_begins}.each do |conf|
      iter = model.append
      iter[0] = _("%s att.\t%s (%s days)\t%s") %
        [conf.people.size, conf.begins, conf.days_to_begins,
         (conf.name.size > 40 ? conf.name[0..39]+'…' : conf.name)]
      iter[1] = conf.id
    end
  end

  # Creates the needed MVC infrastructure for the printing formats
  # listing combobox
  def setup_formats_list(combo)
    model = setup_combobox(combo)
    populate_formats_list(model)

    # The first item, if present should be active at instantiation.
    combo.active=0
  end

  # Populates the printing formats listing combobox
  def populate_formats_list(model)
    model.clear
    NametagFormat.find(:all, :order => :position).each do |fmt|
      iter = model.append
      iter[0] = _("%s cm\t%s") % [fmt.size(:cm), fmt.name]
      iter[1] = fmt.id
    end
  end

  # _Actually_ creates the needed MVC infrastructure for a generic
  # combobox. This function is called by setup_conferences_list and
  # setup_formats_list, and was separated just by DRYness sake.
  def setup_combobox(combo)
    model = Gtk::ListStore.new(String, Integer)
    cell = Gtk::CellRendererText.new()
    combo.pack_start(cell, true)
    combo.add_attribute(cell, 'text', 0)

    combo.set_model(model)
    model
  end

  # Sets the statusbar message to the specified text
  def set_status(text)
    status = @glade['statusbar']
    status.pop(status.get_context_id('status_msg'))
    status.push(status.get_context_id('status_msg'), text)
  end

  # Sends the currently selected person's nametag to the printer
  def print_label_for(person)
    begin
      ZebraLabel.new(person, NametagFormat.find(@format_id))
    rescue Errno::EACCES, Errno::EPERM, Errno::EBUSY, Errno::ENOENT,
      Errno::ENODEV => err
      set_status _('Error printing label: %s') % err.to_s
    end
  end
end

# Actually generates the physical nametags labels
class ZebraLabel
  include GetText

  # Specifies which printer port to use; defaults to /dev/lp0
  def self.set_printer_port(dest)
    @@printer_port = dest || '/dev/lp0'
  end

  # Specifies which charset to use for printing; defaults to
  # CP850
  def self.set_charset(dest)
    @@printer_charset = dest || 'CP850'
  end

  # Prints the specified nametag label using the specified format. If
  # no printer port was defined via #set_printer_port
  def initialize(person, format)
    data = format.generate_for(person)
    begin
      data = Iconv.conv(@@printer_charset, 'UTF-8', data)
    rescue Iconv::InvalidEncoding
      warn _('Invalid output charset "%s" specified - Printing as UTF-8') %
        @@printer_charset
    end
    File.open(@@printer_port, 'a') {|out| out.print(data)}
  end
end
