class CertifImages < ActiveRecord::Migration
  class Logo < ActiveRecord::Base; end

  def self.up
    add_column :logo, :is_certificate, :boolean, :default => false, :null => false
    Logo.find(:all).map {|l| l.is_certificate = false; c.save}
  end

  def self.down
    Logo.find(:all).select {|l| l.is_certificate?}.each {|l| l.destroy}
    remove_column :logo, :is_certificate
  end
end
