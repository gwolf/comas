# = Translation - Handle translation for strings in the database
#
# === Why?
#
# Comas uses GetText for the system translation. GetText is a very
# powerful, scalable and widely used translation system - But it does
# not fare very well with dynamic content, as translations must be
# compiled. That's why, for all database-stored content, we introduced
# this ad-hoc, homegrown and lightweight translation system.
#
# Translation was modelled to be similar in behaviour to GetText - You
# should populate your database with the strings in the default
# language. We advise you to stick to English as the default language,
# as to keep consistency with the rest of the Comas system, even if
# your installation's main language is different.
#
# === What?
#
# This system will basically cover two kinds of translation:
#
# * Column names (for the Person and Conference classes/tables)
# * Catalog rows (for any system-defined catalog)
#
# === Table qualifiers
#
# To ensure no name collisions on two different domains force you into
# choosing a single translation for both, catalog rows will be
# prefixed for translation with the catalog's name and a vertical bar
# - i.e. if you have an 'Auditorium' entry in your 'Room' catalog, the
# corresponding translation key will be 'Room|Auditorium'. This
# qualifier will be automatically dropped when the translation is
# requested, even if no string has yet been specified (only
# 'Auditorium' will be shown).
#
# === Regular usage
#
# To use a Translation-based string, use the #for class method: 
#
#    Translation.for('something to be translated')
class Translation < ActiveRecord::Base
  validates_presence_of :base
  validates_presence_of :lang
  validates_uniqueness_of :base, :scope => :lang

  #:nodoc:
  class NotYetTranslated < Exception; end

  # Gets the translation for the specified string on the currently
  # selected locale (or the locale specified as a second parameter).
  #
  # If the translation has not yet been made for this language, an
  # empty Translation will be stored in the database (ready for the
  # system administrator to fill in), and the original string (minus
  # any table qualifiers - see the class' documentation) will be returned.
  def self.for(str, lang=Locale.current.language)
    begin
      trans = self.find_by_base(str, :conditions =>
                                ['lang = ?', lang]).translated
      raise NotYetTranslated if trans.nil?
      trans
    rescue NoMethodError, NotYetTranslated => err
      self.create_empty_for(str, lang) if err.is_a?(NoMethodError)
      str.gsub(/^.+\|/, '')
    end
  end

  # Creates a new, empty Translation object for the specified string
  # and language. The language can be specified as the second argument
  # (defaults to the currently defined language)
  def self.create_empty_for(str, lang=Locale.current.language)
    new = self.new(:base => str, :lang => lang)
    new.save!
    new
  end

  # Gets the pending translations (i.e. those that have a null or
  # empty translation) for the specified language. This will invoke
  # #create_blanks, in order to report not only the empty strings, but
  # the missing ones as well.
  def self.pending(lang=Locale.current.language)
    self.create_blanks
    self.find(:all, :conditions =>
              ['lang = ? AND COALESCE(translated, \'\') = ?', lang, ''])
  end

  # Find all the translatable strings and create them (leaving them as
  # empty strings if they are not already defined) in the current
  # language.
  def self.query_db_for_strings
    # "Touch" Person and Proposal first, as they might dynamically
    # create catalog models (see acts_as_magic_model)
    Person
    Proposal

    catalogs = self.connection.catalogs.map { |cat|
      begin
        catalog = cat.classify.constantize
      rescue NameError
        # This looks like a catalog, but is not defined. Skip it.
      end
    }.reject {|c| c.nil?}
    # Add some tables not recognized as catalogs, but which work as such
    catalogs << AdminTask

    catalogs.uniq.sort_by {|c| c.to_s}.each do |cat|
      cat.find(:all).each do |elem|
        self.for('%s|%s' % [cat.to_s, elem.name])
      end
    end
  end

  # Find all the translatable strings registered for all the defined
  # languages, and create blank (empty) translations for whichever
  # languages they are not yet defined
  def self.create_blanks
    languages = {}
    strings = {}
    trans = Translation.find(:all)
    trans.each do |t|
      languages[t.lang] = 1 unless languages.has_key?(t.lang)
      strings[t.base] ||= {} unless strings.has_key?(t.base)
      strings[t.base][t.lang] = t.translated
    end

    languages.keys.each do |lang|
      strings.keys.each do |str|
        next if strings[str].has_key?(lang)
        Translation.new(:lang => lang, :base => str).save
      end
    end
  end
end
