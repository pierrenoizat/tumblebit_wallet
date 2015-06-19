class VisitorsController < ApplicationController
  
  def index
    @tree = Tree.first
  end
  
end
