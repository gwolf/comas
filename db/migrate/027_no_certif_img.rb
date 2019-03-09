class CertifImages < ActiveRecord::Migration
  # Reverts migration #24
  class Logo < ActiveRecord::Base; end

  def self.up
    Logo.find(:all).select {|l| l.is_certificate?}.each {|l| l.destroy}
    remove_column :logo, :is_certificate
  end
  def self.down
    add_column :logo, :is_certificate, :boolean, :default => false, :null => false
    Logo.find(:all).map {|l| l.is_certificate = false; c.save}
  end
end
