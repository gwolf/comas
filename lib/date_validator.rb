#
# Distributed with Rails Date Kit
# http://www.methods.co.nz/rails_date_kit/rails_date_kit.html
#
# - Adds a parse_date class method to the Ruby Date class for a wide range of
#   user friendly date string conversions.
# - Adds a date_validator to Rails validations.
# - Overrides the Rails ActiveRecord::ConnectionAdapters::Column.string_to_date
#   method to support the parse_date date formats.
#
# To use: drop this file into ./lib, require it into your model and then
# validate dates with the validates_dates validator.
#
# Change Date.parse_date if you need different date input formats.
#
# Author:  Stuart Rackham <srackham@methods.co.nz>
# License: This source code is released under the MIT license.
#

# Add date string parser class method to Date class.
#
class Date

  # Parse date string with one of the following formats:
  #
  # * ISO date format: yyyy-mm-dd, for example '2001-12-25'
  # * d[ mmm[ yy[yy]]]: examples: '22', '22 feb', '22 feb 2003',
  #   '22 feb 03', '22 February 2003'
  # * +n[units] or -n[units]: Date from today: examples: '+22', '+22 days',
  #   '+22d', '-4 weeks', '-4w', '-4week', '+6 months', '+6m', '+6month',
  #   '-2 years', '-2y'
  #
  # The string argument is first converted to a string with #to_s.
  # Returns nil if passed nil or an empty string.
  # Raises ArgumentError if string can't be parsed.
  #
  def self.parse_date(string)
    string = string.to_s.strip.downcase
    return nil if string.empty?
    today = Date.today
    if string =~ /^(\d{4})-(\d{2})-(\d{2})$/
      # ISO date format.
      date_array = ParseDate.parsedate(string, true)
      begin
        result = Date.new(date_array[0], date_array[1], date_array[2])
      rescue
        raise ArgumentError
      end
    elsif string =~ /^(\d{1,2})(?:(?:\s+|-)([a-zA-Z]{3,9})(?:(?:\s+|-)(\d{2}(?:\d{2})?))?)?$/
      # 'd mmmm yyyy' format and abbreviations.
      day = $1
      month = $2 || Date::ABBR_MONTHNAMES[today.month]
      year = $3 || today.year
      date_array = ParseDate.parsedate("#{day} #{month} #{year}", true)
      begin
        result = Date.new(date_array[0], date_array[1], date_array[2])
      rescue
        raise ArgumentError
      end
    elsif string =~ /^([+-]\d+)(?:\s*(d|days?|w|weeks?|m|months?|y|years?))?$/
      # Date intervals.
      n = $1.to_i
      units = $2 || 'days'
      case units.first
      when 'd'
        result = today + n
      when 'w'
        result = today + n*7
      when 'm'
        sign = n <=> 0
        month = today.month + sign * (n.abs % 12)
        year = today.year + sign * (n.abs / 12)
        if month <1
          month += 12
          year -= 1
        elsif month > 12
          month -= 12
          year += 1
        end
        result = Date.new(year, month, today.day)
      when 'y'
        result = Date.new(today.year + n, today.month, today.day)
      end
    else
      raise ArgumentError
    end
    result
  end

end

# Add date_validator to Rails validations.
#
module ActiveRecord::Validations::ClassMethods

  # Validates date values, these can be dates or any formats accepted by
  # Date.parse_date.
  # 
  # For example:
  #
  #   class Person < ActiveRecord::Base
  #     require_dependency 'date_validator'
  #     validates_dates :birthday,
  #                     :from => '1 Jan 1920',
  #                     :to => Date.today,
  #                     :allow_nil => true
  #   end
  #
  # Options:
  # * from - Minimum allowed date. May be a date or a string recognized
  #   by Date.parse_date.
  # * to - Maximum allowed date. May be a date or a string recognized
  #   by Date.parse_date.
  # * allow_nil - Attribute may be nil; skip validation.
  #
  def validates_dates(*attr_names)
    configuration =
      { :message => 'is an invalid date ' \
                    '(here are some valid examples: 23, 23 feb, 23 feb 06, ' \
                    '6 feb 2006, 2006-02-23, +6days, +6d, +6, +2w, -6m, +1y)',
        :on => :save,
      }
    configuration.update(attr_names.pop) if attr_names.last.is_a?(Hash)
    # Don't let validates_each handle allow_nils, it checks the cast value.
    allow_nil = configuration.delete(:allow_nil)
    from = Date.parse_date(configuration.delete(:from))
    to = Date.parse_date(configuration.delete(:to))
    validates_each(attr_names, configuration) do |record, attr_name, value|
      before_cast = record.send("#{attr_name}_before_type_cast")
      next if allow_nil and (before_cast.nil? or before_cast == '')
      begin
        date = Date.parse_date(before_cast)
      rescue
        record.errors.add(attr_name, configuration[:message])
      else
        if from and date < from
          record.errors.add(attr_name,
                            "cannot be less than #{from.strftime('%e-%b-%Y')}")
        end
        if to and date > to
          record.errors.add(attr_name,
                            "cannot be greater than #{to.strftime('%e-%b-%Y')}")
        end
      end
    end
  end

end

# Override default date type cast class method to handle Date.parse_date
# formats (the default implementation returns nil if passed an unrecognized
# date format).
#
class ActiveRecord::ConnectionAdapters::Column
  def self.string_to_date(string)
    return string unless string.is_a?(String)
    Date.parse_date(string) rescue nil
  end
end
