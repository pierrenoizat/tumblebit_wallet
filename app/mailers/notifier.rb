class Notifier < ActionMailer::Base
  default :from => 'hashtre.es'

  # Subject can be set in your I18n file at config/locales/en.yml
  # with the following lookup:
  #
  #   en.notifier.order_received.subject
  
  
  def form_received(contact_form)
    @contact_form = contact_form
    mail :to => "noizat@hotmail.com", :from => "hashtre.es", :subject => 'Hashtre.es Contact Form'
  end
  
end
