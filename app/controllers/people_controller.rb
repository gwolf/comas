class PeopleController < ApplicationController
  def login
    clear_session
  end

  def logout
    clear_session
    flash[:notice] = 'Successfully logged out'
    redirect_to '/'
  end

  def validate
    user = Person.ck_login(params[:login], params[:passwd])
    if user
      dest_url = session[:returnto] || '/'

      session[:user_id] = user.id
      redirect_to dest_url
    else
      flash[:warning] = 'Incorrect user/password'
      redirect_to :action => 'login'
    end
  end

  private
  def clear_session
    session[:user_id] = nil
  end
end
