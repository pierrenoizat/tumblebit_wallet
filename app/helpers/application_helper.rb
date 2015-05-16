module ApplicationHelper
  
  def truncate_node_hash(string)

    if string and string.size >25
      end_string = string[-12,12]
      truncated_string = truncate(string, length: 22, omission: '.......') + end_string
    else
      if string 
        truncated_string = string
      else
        truncated_string = ''
      end
    end

  end # of helper method
  
end
