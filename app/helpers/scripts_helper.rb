module ScriptsHelper
  
  def category_of(script)
    case script
      when "timelocked_address"
        "Timelocked Address"
        
      when "timelocked_2fa"
        "Timelocked 2FA"
        
      when "contract_oracle"
        "Contract Oracle"
        
      when "hashed_timelocked_contract"
        "Hashed Timelocked Contract"
    end
  end
  
end
