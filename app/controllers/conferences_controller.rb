class ConferencesController < ApplicationController
  before_filter :get_conference, :except => [:index, :list]

  def index
    redirect_to :action => :list
  end

  def list
    @conferences = Conference.find(:all)
  end

  def show
    redirect_to :list if !@conference.active?
  end

  protected
  def get_conference
    if id = params[:id]
      @conference = Conference.find(id)
    else
      redirect_to :list
      return false
    end
  end
end
