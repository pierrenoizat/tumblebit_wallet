module ScriptsHelper
  
  def category_of(script)
    case script
      when "time_locked_address"
        "Time Locked Address"
        
      when "time_locked_2fa"
        "Time Locked 2FA"
        
      when "contract_oracle"
        "Contract Oracle"
        
      when "hashed_timelock_contract"
        "Hashed Timelock Contract"
    end
  end
  
end
