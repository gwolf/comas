class Admin < ApplicationController
  def check_auth
    request.path_parameters['controller'] =~ /^admin\/(.+)$/

    if ctrl = $1 and task = AdminTask.find_by_name(ctrl)
      if @user and @user.admin_tasks.include? task
        return true
      end
      flash[:error] = "Access denied"
    end
    flash[:error] = "Invocation error"

    redirect_to '/'
  end
end
