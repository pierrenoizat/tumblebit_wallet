module Paymentable
   extend ActiveSupport::Concern
   
   def valid_json?(json)
       JSON.parse(json)
       return true
     rescue JSON::ParserError => e
       return false
   end

   # methods defined here are going to extend the class, not the instance of it
   module ClassMethods

     # def tag_limit(value)
     #  self.tag_limit_value = value
     # end

   end

   private

   def payment_params
     params.require(:payment).permit(:alice_public_key)
   end

   def set_payment
     @payment = Payment.find(params[:id])
   end
 end