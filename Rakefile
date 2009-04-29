# -*- Ruby -*-
# Add your own tasks in files placed in lib/tasks ending in .rake,
# for example lib/tasks/capistrano.rake, and they will automatically be available to Rake.

require(File.join(File.dirname(__FILE__), 'config', 'boot'))

require 'rake'
require 'rake/testtask'
require 'rake/rdoctask'

require 'tasks/rails'

begin 
  require 'gettext/utils'

  desc "Create mo-files for L10n" 
  task :makemo do
    GetText.create_mofiles(true, "po", "locale")
  end

  desc "Update pot/po files to match new version." 
  task :updatepo do
    MY_APP_TEXT_DOMAIN = "comas" 
    MY_APP_VERSION     = "comas 1.0" 

    string_sources = Dir.glob("{app,lib}/**/*.{rb,erb,rhtml,glade}") 
    string_sources << 'script/nametags' << 'script/create_user' 

    GetText.update_pofiles(MY_APP_TEXT_DOMAIN,
                           string_sources,
                           MY_APP_VERSION)
  end
rescue LoadError => err
  [:updatepo, :makemo].each do |t|
    desc "#{t} ineffective, as gettext is not installed in your system"
    task t do
      puts "#{t} requires gettext - #{err}"
    end
  end
end
