class ContactsController < ApplicationController
  def new
    @contact = Contact.new
  end

  def create
    @contact = Contact.new(params[:contact])
    @contact.request = request
    boolean = false
    
    boolean = EmailValidator.valid?(@contact.email) # boolean
    
    if (Notifier.form_received(@contact).deliver and boolean)
      flash.now[:notice] = 'Thanks for your message!'
    else
      @contact.email = ""
      flash.now[:notice] = 'There was a problem with the email address you entered.'
      render :new
    end
    
  end
end
