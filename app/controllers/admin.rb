class Admin < ApplicationController
  protected
  def check_auth
    ctrl = request.path_parameters['controller']

    if task = AdminTask.find_by_sys_name(ctrl)
      if @user and @user.admin_tasks.include? task
        return true
      end
      flash[:error] = _ "Access denied"
    end
    flash[:error] = _ "Invocation error"

    redirect_to '/'
  end
end
