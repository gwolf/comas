class CertificatesController < ApplicationController
  def verif
    conf = Conference.find_by_id(params[:conference_id])
    pers = Person.find_by_id(params[:person_id])

    @conf_name = conf.name
    @pers_name = pers.name
    @has_certif = pers.certificate_for?(conf)
  end

  protected
  def check_auth
    true
  end
end
