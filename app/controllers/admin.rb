class Admin < ApplicationController
  protected
  def check_auth
    ctrl = request.path_parameters['controller']

    if task = AdminTask.find_by_sys_name(ctrl)
      if @user and @user.has_admin_task? task
        return true
      end
      flash[:error] << _('Access denied')
    else
      flash[:error] << _('Invocation error')
    end

    redirect_to :controller => 'people', :action => 'login'
    return false
  end
end
