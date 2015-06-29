class VisitorsController < ApplicationController
  
  def index
    @tree = Tree.first
    @contact = Contact.new # for contact form
    @visitor = Visitor.new  # for newsletter subscription
  end

  def new
    @visitor = Visitor.new
  end

  def create
    @visitor = Visitor.new(params.require(:visitor).permit(:email))
    if @visitor.save
      redirect_to root_path, notice: "Signed up #{@visitor.email}."
    else
      render :new
    end
  end

end
