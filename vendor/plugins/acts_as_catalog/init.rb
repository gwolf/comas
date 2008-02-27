$:.unshift "#{File.dirname(__FILE__)}/lib"
require 'acts_as_catalog'
require 'catalog_migrations'
ActiveRecord::Base.send :include, GWolf::UNAM::ActsAsCatalog
ActiveRecord::ConnectionAdapters::AbstractAdapter.send :include, GWolf::UNAM::CatalogMigrations
