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
        
      when "tumblebit_puzzle"
        "Tumblebit Puzzle Contract"
        
      when "segwit_p2sh_p2wpkh"
        "SegWit P2SH-P2WPKH"
        
      when "tumblebit_escrow_contract"
        "Tumblebit Escrow Contract"
    end
  end
  
end
