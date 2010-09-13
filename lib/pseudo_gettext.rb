=begin
  pseudo_gettext.rb - GetText for the users who doesn't have
  Ruby-GetText-Package.

  Copyright (C) 2006  Masao Mutoh

  You may redistribute it and/or modify it under the same
  license terms as Ruby.

  $Id$
=end

begin
  require 'gettext_rails'
rescue LoadError
  begin
    require 'gettext/rails'
  rescue LoadError
  end
end

unless defined? GetText
  module GetText
    def _(str); str; end
    def s_(str); str; end
    def N_(str); str; end
    def n_(str1, str2); str; end
    def Nn_(str1, str2); str; end
    def bindtextdomain(domain, opts = {}); end
    def textdomain(domain); end
  end
  class ActiveRecord::Base
    include GetText
    extend GetText
    def self.untranslate(*w);end
    def self.untranslate_all;end
  end
  class ActionController::Base
    include GetText
    extend GetText
    def self.init_gettext(textdomain, opts = {}); end
  end
  class ActionView::Base
    include GetText
    extend GetText
  end
  class ::String
    alias :_old_format_m :%
    def %(args)
      if args.kind_of?(Hash)
        ret = dup
        args.each {|key, value|
          ret.gsub!(/\%\{#{key}\}/, value.to_s)
        }
        ret
      else
        ret = gsub(/%\{/, '%%{')
        begin
          ret._old_format_m(args)
        rescue ArgumentError
          $stderr.puts "  The string:#{ret}"
          $stderr.puts "  args:#{args.inspect}"
        end
      end
    end
  end
end
