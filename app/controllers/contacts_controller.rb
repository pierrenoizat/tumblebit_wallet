class ContactsController < ApplicationController
  def new
    @contact = Contact.new
  end

  def create
    @contact = Contact.new(params[:contact])
    @contact.request = request
    
    boolean = (@contact.name and @contact.email)
    if boolean
      string = @contact.email
      boolean = (string == /\A([\w\.%\+\-]+)@([\w\-]+\.)+([\w]{2,})\z/i.match(string)[0])
    end
    
    if Notifier.form_received(@contact).deliver and boolean
      flash.now[:notice] = 'Thanks for your message!'
    else
      render :new
    end
    
  end
end
