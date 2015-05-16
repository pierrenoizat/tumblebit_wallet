module TreeWorker
  @queue = :id

  def self.perform(id)
    
    @tree = Tree.find_by_id(id)
    
    tree_id = @tree.id
    path_index = 0

    @tree.height = 1
    @tree.error_count = 0
    @tree.count = 100 
    if @tree.depth.nil?
      @tree.depth = 1
    end
    @tree.save
    
    #########
    @leaf_nodes = @tree.leaf_nodes
    if @leaf_nodes
      @leaf_nodes.each do |leaf_node|
        leaf_node.destroy # delete previous version of leaf_nodes
      end
    end
      
    @nodes = @tree.nodes
    if @nodes
      @nodes.each do |node|
        node.destroy # delete previous version of nodes
      end
    end
    ######################### Parse leaf nodes from uploaded (account list) file
    require 'openssl'
    
    string = OpenSSL::Digest::SHA256.new.digest(id.to_s).unpack('H*').first
    string = string[0..5]
    if File.exists?("tree_" + "#{string}" + ".csv")
      File.delete("tree_#{string}.csv") # delete any previous version of tree.csv file
      end
  
      data = open(@tree.roll.url).read
    
      file_sum = 0
      r = 1

    require 'csv'

    CSV.parse(data) do |row|
        user_array = []
        @leaf_node = LeafNode.new
        
        row.each do |s|
          user_array << s
          
          user = user_array[0]
          sum = user_array[1]
          file_sum = file_sum + sum.to_f 
          nonce = OpenSSL::Random.random_bytes(16).unpack("H*").first
          
          salt_string = $SALT_STRING

          @leaf_node.name = user.to_s
          @leaf_node.credit = sum.to_f
          @leaf_node.nonce = nonce.to_s
          @leaf_node.tree_id = tree_id
          @leaf_node.height = path_index
          @leaf_node.save
          
          if @leaf_node.errors.any?
            @tree.error_count += @leaf_node.errors.count
          end
          
          end # do |s|
          r+=1
        end # do |row| (read input file)
        
    count = r-1
    
    @leaf_nodes = LeafNode.where('tree_id' => tree_id).all.shuffle
    leaf_count = @leaf_nodes.count
    if leaf_count != count
      @tree.error_count = 10000
    end
    
    @tree.count = count
    @tree.save
    
    ##################### writes account names and their balance to tree.csv file in app tmp folder
    
    require 'openssl'
    
    string = OpenSSL::Digest::SHA256.new.digest(tree_id.to_s).unpack('H*').first
    string = string[0..5]
    CSV.open("tmp/tree_#{string}.csv", "ab") do |csv| 
      csv << ["Tree as of " + "#{Time.now}"]
      csv << ["#{count.to_s + " users"}"]

      @leaf_nodes.each do |leaf|
        csv << [leaf.name, leaf.credit, leaf.nonce, leaf.leaf_hash]
        end

      csv << ["TOTAL = " + file_sum.to_s + " BTC"]
      
    end # of CSV.open (writing to tree.csv)
    
    ##################### writes leaf_nodes to json file in app tmp folder
    require 'json'
    tempHash = { }
    @leaf_nodes.each do |leaf|
      tempHash.merge!(leaf.as_json)
    end

    File.open("tmp/tree_#{tree_id}.json","w") do |f|
      f.write(tempHash.to_json)
    end
  
  ############################## get first internal nodes from leaves
  k = 1

  @leaf_nodes.each do |leaf|
      # value.user, value.sum, value.nonce,value.leaf_node_hash
        if k.odd?
          @node = Node.new # left, right, sum, node_hash, height
          @node.height = 1
          @node.left = leaf.leaf_hash
          @node.sum = leaf.credit

          if k == count # last leaf node gets height = 1 instead of 0 if odd count
            @node.height = 1
            @node.left = leaf.name
            @node.right = leaf.nonce
            @node.sum = leaf.credit
            @node.node_hash = leaf.leaf_hash
            @node.tree_id = tree_id
            @node.save
          end

        else # k even
          @node.right = leaf.leaf_hash
          @node.sum += leaf.credit
          message = "#{@node.sum.to_s}|#{@node.left}|#{@node.right}"
          @node.node_hash = OpenSSL::Digest::SHA256.new.digest(message).unpack('H*').first
          @node.tree_id = tree_id 
          @node.save

        end # if k.odd ?
        k+=1

      end # each do leaf
      ############################## get other internal nodes all the way to the root  
      
      height = 1
      depth = @tree.depth # figure out how deep the root is

      @nodes = Node.where('height' => 1).all
      unless @nodes.blank?
      @nodes = @nodes.select { |node| node.tree_id == @tree.id }
      end

      while @nodes.count > 1

        @nodes = Node.where('height' => height).all.shuffle
        unless @nodes.blank?
        @nodes = @nodes.select { |node| node.tree_id == @tree.id }
        end

        if @nodes.count > 1 # if not root, get internal nodes
          @nodes = @nodes.sort_by { |obj| obj.left.length } # make sure that last odd leaf node becomes internal node of height 1
          count = @nodes.count # if count = 2 then height of tree (root) is height+1

          k = 1

          @nodes.each do |value| # value.left, right, sum, node_hash, height

            if k.odd?
              @node = Node.new # left, right, sum, node_hash, height
              @node.tree_id = @tree.id
              @node.height = height + 1
              @node.left = value.node_hash
              @node.sum = value.sum

              if k == count # last internal node of height height gets height = height+1 if odd count
                @node.height = height + 1
                @node.left = value.left
                @node.right = value.right
                @node.sum = value.sum
                @node.node_hash = value.node_hash
                @node.save
              end

            else # k even
              @node.right = value.node_hash
              @node.sum += value.sum
              
              message = "#{@node.sum.to_s}|#{@node.left}|#{@node.right}"
              @node.node_hash = OpenSSL::Digest::SHA256.new.digest(message).unpack('H*').first
              
              @node.save
            end
            k+=1
            end # each do
            height += 1

            @nodes = Node.where('height' => height).all
            unless @nodes.blank?
            @nodes = @nodes.select { |node| node.tree_id == @tree.id }
            end

            count = @nodes.count
            if @tree.count > count
              @tree.count = count
            end
            @tree.height = height
            if height > depth
              @tree.depth = height
            end
            @tree.save
          end # if not root (if height + 1 is blank because height at root, do nothing)
          end #  of while loop, meaning tree is now complete
          
            height += 1
            count = @nodes.count
            if @tree.count > count
              @tree.count = count
            end
            @tree.height = height
            if height > depth
              @tree.depth = height
            end
            
            @tree.save 
  
  end # of method
end # of module