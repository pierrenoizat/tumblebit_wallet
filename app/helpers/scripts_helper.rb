module ScriptsHelper
  
  def category_of(script)
    case script
        
      when "tumblebit_puzzle"
        "Tumblebit Puzzle Contract"
        
      when "tumblebit_escrow_contract"
        "Tumblebit Escrow Contract"
    end
  end
  
end
