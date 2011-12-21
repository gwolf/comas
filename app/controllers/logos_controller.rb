class LogosController < ApplicationController
  ['data', 'medium', 'thumb'].each do |size|
    eval "def #{size}
            return render(:text => '',
                          :status => '304 Not Modified') if is_cached?(params[:id])
            logo = Logo.find(params[:id])
            send_logo(logo.updated_at, logo.#{size})
          end"
  end

 private
  def is_cached?(logo_id)
    # Why the explicit SQL? Because we precisely want to avoid fetching the
    # whole logo from the DB if it is already cached - Get only the update
    # time.
    logo = Logo.find_by_sql(['SELECT id, updated_at FROM logos WHERE id=?',
                             logo_id]).first
    minTime = Time.rfc2822(request.env["HTTP_IF_MODIFIED_SINCE"]) rescue nil

    return true if minTime and logo.updated_at <= minTime
    false
  end

  def send_logo (updated_at, data)
    response.headers['Last-Modified'] = updated_at.httpdate
    send_data data, :type => 'image/png', :disposition => 'inline'
  end

  def check_auth
    public = [:show]
    return true if public.include? request.path_parameters['action'].to_sym
  end
end
