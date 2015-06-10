module TreeWorker
  @queue = :id
  
  
  include ActionView::Helpers::AssetTagHelper
  include ActionView::Helpers::NumberHelper
  include ActionView::Helpers::TextHelper
  include ActionView::Helpers::DateHelper

  require 'json'

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
    
    ##################### writes account names and their balance to tree_#{string}.csv file in app tmp folder
    
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
  
  ############################## get first internal nodes from leaves
  k = 1

  @leaf_nodes.each do |leaf|
      # value.user, value.sum, value.nonce,value.leaf_node_hash
        if k.odd?
          @node = Node.new # left, right, sum, node_hash, height
          @node.height = 1
          @node.left = leaf.leaf_hash
          @node.sum = leaf.credit
          @node.left_id = leaf.id
          @node.save
          leaf.node_id = @node.id
          leaf.save

          if k == count # last leaf node gets height = 1 instead of 0 if odd count
            @node.height = 1
            @node.left = leaf.name
            @node.right = leaf.nonce
            @node.sum = leaf.credit
            @node.node_hash = leaf.leaf_hash
            @node.tree_id = tree_id
            @node.right_id = nil
            @node.save
          end

        else # k even
          @node.right = leaf.leaf_hash
          @node.sum += leaf.credit
          message = "#{@node.sum.to_s}|#{@node.left}|#{@node.right}"
          @node.node_hash = OpenSSL::Digest::SHA256.new.digest(message).unpack('H*').first
          @node.tree_id = tree_id
          @node.right_id = leaf.id
          @node.save
          leaf.node_id = @node.id
          leaf.save

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
              @node.left_id = value.id

              if k == count # last internal node of height height gets height = height+1 if odd count
                @node.height = height + 1
                @node.left = value.left
                @node.right = value.right
                @node.sum = value.sum
                @node.node_hash = value.node_hash
                @node.right_id = nil
                @node.save
              end

            else # k even
              @node.right = value.node_hash
              @node.sum += value.sum
              
              message = "#{@node.sum.to_s}|#{@node.left}|#{@node.right}"
              @node.node_hash = OpenSSL::Digest::SHA256.new.digest(message).unpack('H*').first
              @node.right_id = value.id
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
            
            # intialize attribute node_path for the internal nodes
            # @nodes = @tree.nodes  does NOT work !
            @nodes = Node.select { |node| node.tree_id == id } 
            
            @nodes.each do |node|  ########################################
              k = node.height
              @selected_nodes = @nodes.select { |obj| ((obj.left_id == node.id) and (obj.height == node.height + 1)) }
              @next_node = @selected_nodes.first
              if @next_node
                node.node_path = "0"
              else
                @selected_nodes = @nodes.select { |obj| ((obj.right_id == node.id) and (obj.height == node.height + 1)) }
                @next_node = @selected_nodes.first
                if @next_node
                  node.node_path = "1"
                else
                  node.node_path = ""
                end
              end
              k += 1
              while k < (@tree.height - 1)
                # get nodes just above current node
                @selected_nodes = @nodes.select { |obj| ((obj.left_id == @next_node.id) and (obj.height == @next_node.height + 1)) }
                @parent_node = @selected_nodes.first

                if @parent_node
                  node.node_path += "0" # rightmost digit of leaf_path points to highest node
                else
                  @selected_nodes = @nodes.select { |obj| ((obj.right_id == @next_node.id) and (obj.height == @next_node.height + 1)) }
                  @parent_node = @selected_nodes.first

                  if @parent_node
                    node.node_path += "1"
                  end
                end
                @next_node = @parent_node
                k += 1
              end # of while k < @tree.height -1

              node.save
            end # of do |node| ################################################
            
            @nodes = Node.select { |node| ((node.tree_id == id) and (node.height == 1)) } # get nodes just above leaves

            @leaf_nodes = LeafNode.where('tree_id' => id).all

            @leaf_nodes.each do |leaf| ######################################

              @selection = @nodes.select { |node| ((node.left_id == leaf.id) and (node.height == 1)) }
              @node = @selection.first
              if @node
                leaf_path = "0" + @node.node_path
              else
                @selection = @nodes.select { |node| ((node.right_id == leaf.id) and (node.height == 1)) }
                @node = @selection.first
                leaf_path = "1" + @node.node_path
              end
              leaf.leaf_path = leaf_path
              leaf.save
            end # of do |leaf|

  puts "#{@tree.name} analysis in progress"
  ################################################## build the json representation of the tree for d3

    h = height-1
    
    @nodes = Node.select { |node| ((node.tree_id == @tree.id) and (node.height == h)) } # get root node
    @node = @nodes.first
    
    if @nodes.count == 1
      puts "#{@tree.name} root found"
    end
    
    # intialize @my_json, a json, serialized form of the tree with the first two levels of nodes from the root down.
     @my_json = {
      :name => "#{@node.node_hash}", :node_id => "#{@node.id}", :sum => "#{@node.sum}",
      :children => [
          {:name => "#{@node.left}", :node_id => "#{@node.left_id}"},
          {:name => "#{@node.right}", :node_id => "#{@node.right_id}"}
          ]  
      }
      
      h -= 2

      a = Array[ @node.left_child.single_child?, @node.right_child.single_child? ]
      case a
        
      when [ true, false ] # left node is connected to a single, replicate node and right node must have 2 children nodes
        @my_json = {
          :name => "#{@node.truncated_node_hash}", :node_id => "#{@node.id}", :sum => "#{@node.sum}",
          :children => [
              {:name => "#{@node.left}", :children => [{:name => "#{@node.left}", :sum => "#{@node.left_child.sum}", :node_id => "#{@node.left_child.left_id}"}]},
              {:name => "#{@node.right}", 
               :children => [
                 {:name => "#{@node.right_child.left}", :sum => "#{@node.right_child.left_child.sum}",:node_id => "#{@node.right_child.left_id}",:left_id => "#{@node.right_child.left_child.left_id}",:right_id => "#{@node.right_child.left_child.right_id}"},
                 {:name => "#{@node.right_child.right}", :sum => "#{@node.right_child.right_child.sum}",:node_id => "#{@node.right_child.right_id}",:left_id => "#{@node.right_child.right_child.left_id}",:right_id => "#{@node.right_child.right_child.right_id}"}
                ]
                }
              ]  
          }
          
      when [ false, true ] # right node is connected to a single, replicate node and left node must have 2 children nodes
        @my_json = {
          :name => "#{@node.node_hash}", :node_id => "#{@node.id}", :sum => "#{@node.sum}",
          :children => [
              {:name => "#{@node.left}", 
               :children => [
                 {:name => "#{@node.left_child.left}", :sum => "#{@node.left_child.left_child.sum}",:node_id => "#{@node.left_child.left_id}",:left_id => "#{@node.left_child.left_child.left_id}",:right_id => "#{@node.left_child.left_child.right_id}"},
                 {:name => "#{@node.left_child.right}", :sum => "#{@node.left_child.right_child.sum}",:node_id => "#{@node.left_child.right_id}",:left_id => "#{@node.left_child.right_child.left_id}",:right_id => "#{@node.left_child.right_child.right_id}"}
                ]
                },
              {:name => "#{@node.right}", :children => [{:name => "#{@node.right}", :sum => "#{@node.right_child.sum}",:node_id => "#{@node.right_child.left_id}"}]}
              ]  
            }
            
      when [ false, false ] # both nodes connected each to 2 children
        @my_json = {
          :name => "#{@node.node_hash}",
          :children => [
            {:name => "#{@node.left}", 
             :children => [
               {:name => "#{@node.left_child.left}", :sum => "#{@node.left_child.left_child.sum}",:node_id => "#{@node.left_child.left_id}",:left_id => "#{@node.left_child.left_child.left_id}",:right_id => "#{@node.left_child.left_child.right_id}"},
               {:name => "#{@node.left_child.right}", :sum => "#{@node.left_child.right_child.sum}",:node_id => "#{@node.left_child.right_id}",:left_id => "#{@node.left_child.right_child.left_id}",:right_id => "#{@node.left_child.right_child.right_id}"}
                ]
            },
            {:name => "#{@node.right}", 
             :children => [
               {:name => "#{@node.right_child.left}", :sum => "#{@node.right_child.left_child.sum}",:node_id => "#{@node.right_child.left_id}",:left_id => "#{@node.right_child.left_child.left_id}",:right_id => "#{@node.right_child.left_child.right_id}"},
               {:name => "#{@node.right_child.right}", :sum => "#{@node.right_child.right_child.sum}",:node_id => "#{@node.right_child.right_id}",:left_id => "#{@node.right_child.right_child.left_id}",:right_id => "#{@node.right_child.right_child.right_id}"}
              ]
              }
            ]  
          }
      else
        puts "I have no idea what to do with that."
      end
      
      # @my_json =  TreeWorker.append_nodes(@my_json, @node.tree_id) # returns @my_json completed with internal nodes through the leaves
      
      h = TreeWorker.json_height(@my_json)
      puts "hauteur ", h
      k = @tree.height - 4
      while k > 0
        @my_json = TreeWorker.append_nodes(@my_json, @node.tree_id)
        k -= 1
      end
      
      # save @my_json to a json file
      File.open("tmp/tree_#{tree_id}.json","w") do |f|
            f.write("#{@my_json.to_json}")
          end
      puts "#{@tree.name} upload to S3 started"
      # upload to Amazon S3
      
      s3 = AWS::S3.new(
      :access_key_id     => 'AKIAISHH6QIJ3R7Q2HXQ',
          :secret_access_key => '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'
      )
      
      bucket = s3.buckets[Figaro.env.s3_bucket]

      obj = bucket.objects["tree_#{tree_id}.json"]
      obj.write(:file => "#{Rails.root}/tmp/tree_#{tree_id}.json")
      
      @tree.url = obj.url_for(:read,
                           :response_content_type => "application/json")
      @tree.save
      
      puts "#{@tree.name} analysis job successfully completed"
      puts @tree.url
          
      @my_json

    end
    
      
      def TreeWorker.json_height(var) # computes the min height of nodes from root per the json representation argument
        hi = 0
        jsonvar = var
        array_var = []

        while jsonvar
            array_var = jsonvar[:children]

            if array_var
              jsonvar=array_var[0]
              hi +=1
            else
              jsonvar=nil
            end

        end
        hi

      end


      def TreeWorker.append_nodes(jvar, id) # var = current json representation of the tree with tree.id = id

        h = TreeWorker.json_height(jvar)
        @tree = Tree.find_by_id(id)

        # get nodes where node.height = tree.height-h-2, first nodes to be appended
        @nodes = Node.where('height' => @tree.height - h - 2).all
        unless @nodes.blank?
        @nodes = @nodes.select { |node| node.tree_id == id }
        end

        if @nodes.count > 0
          # append nodes, if tree height > 4, i.e if there are nodes with height > 3

          @nodes.each do |node|  ########################################

            jsonvar = jvar
            @new_jsonvar = {}
            @node_json = {}
            @new_jsonvar = jvar
            @node_json = {:name => "#{node.node_hash}", :sum => "#{node.sum}",:node_id => "#{node.id}", :path => "#{node.node_path}" }

            @new_jsonvar = TreeWorker.update_json(jsonvar,@node_json)

          end # of do |node| #############################################

        else
          # append leaf nodes

          @leaf_nodes = LeafNode.where('tree_id' => id).all

          @leaf_nodes.each do |leaf| ######################################

            jsonvar = jvar
            @new_jsonvar = {}
            @node_json = {}
            @new_jsonvar = jvar
            @node_json = {:name => "#{leaf.leaf_hash}", :sum => "#{leaf.credit}",:node_id => "#{leaf.id}", :path => "#{leaf.leaf_path}" }

            @new_jsonvar = TreeWorker.update_json(jsonvar,@node_json)

          end # of do |leaf|  ###########################################

        end

        @new_jsonvar

      end  # of method append_nodes



      def TreeWorker.update_json(jvar,node_json)

        new_jvar = {}
        new_jvar = jvar
        path = node_json[:path]

        #######################
        a = path.split(//)  # converts node_path string into an array of characters
        for i in 0..a.count
          a[i] = a[i].to_i # convert a to an array of integers
        end

        case path.length

        when 3
          if a[0] == 0
            if new_jvar[:children][a[2]][:children][a[1]][:children].blank?
              new_jvar[:children][a[2]][:children][a[1]][:children] = [node_json]
            else
              new_jvar[:children][a[2]][:children][a[1]][:children][0] = node_json
            end
          else
            if new_jvar[:children][a[2]][:children][a[1]][:children].blank?
              new_jvar[:children][a[2]][:children][a[1]][:children] = [ {}, node_json ]
            else
              new_jvar[:children][a[2]][:children][a[1]][:children] << node_json
            end
          end

        when 4
          if a[0] == 0
            if new_jvar[:children][a[3]][:children][a[2]][:children][a[1]][:children].blank?
              new_jvar[:children][a[3]][:children][a[2]][:children][a[1]][:children] = [node_json]
            else
              new_jvar[:children][a[3]][:children][a[2]][:children][a[1]][:children][0] = node_json
            end
          else
            if new_jvar[:children][a[3]][:children][a[2]][:children][a[1]][:children].blank?
              new_jvar[:children][a[3]][:children][a[2]][:children][a[1]][:children] = [ {}, node_json ]
            else
              new_jvar[:children][a[3]][:children][a[2]][:children][a[1]][:children] << node_json
            end
          end

        when 5
          if a[0] == 0
            if new_jvar[:children][a[4]][:children][a[3]][:children][a[2]][:children][a[1]][:children].blank?
              new_jvar[:children][a[4]][:children][a[3]][:children][a[2]][:children][a[1]][:children] = [node_json]
            else
              new_jvar[:children][a[4]][:children][a[3]][:children][a[2]][:children][a[1]][:children][0] = node_json
            end
          else
            if new_jvar[:children][a[4]][:children][a[3]][:children][a[2]][:children][a[1]][:children].blank?
              new_jvar[:children][a[4]][:children][a[3]][:children][a[2]][:children][a[1]][:children] = [ {}, node_json ]
            else
              new_jvar[:children][a[4]][:children][a[3]][:children][a[2]][:children][a[1]][:children] << node_json
            end
          end

        when 6

          if a[0] == 0
            if new_jvar[:children][a[5]][:children][a[4]][:children][a[3]][:children][a[2]][:children][a[1]][:children].blank?
              new_jvar[:children][a[5]][:children][a[4]][:children][a[3]][:children][a[2]][:children][a[1]][:children] = [node_json]
            else
              new_jvar[:children][a[5]][:children][a[4]][:children][a[3]][:children][a[2]][:children][a[1]][:children][0] = node_json
            end
          else
            if new_jvar[:children][a[5]][:children][a[4]][:children][a[3]][:children][a[2]][:children][a[1]][:children].blank?
              new_jvar[:children][a[5]][:children][a[4]][:children][a[3]][:children][a[2]][:children][a[1]][:children] = [ {}, node_json ]
            else
              new_jvar[:children][a[5]][:children][a[4]][:children][a[3]][:children][a[2]][:children][a[1]][:children] << node_json
            end
          end

        when 7  # when tree height is eight

          if a[0] == 0
            if new_jvar[:children][a[6]][:children][a[5]][:children][a[4]][:children][a[3]][:children][a[2]][:children][a[1]][:children].blank?
              new_jvar[:children][a[6]][:children][a[5]][:children][a[4]][:children][a[3]][:children][a[2]][:children][a[1]][:children] = [node_json]
            else
              new_jvar[:children][a[6]][:children][a[5]][:children][a[4]][:children][a[3]][:children][a[2]][:children][a[1]][:children][0] = node_json
            end
          else
            if new_jvar[:children][a[6]][:children][a[5]][:children][a[4]][:children][a[3]][:children][a[2]][:children][a[1]][:children].blank?
              new_jvar[:children][a[6]][:children][a[5]][:children][a[4]][:children][a[3]][:children][a[2]][:children][a[1]][:children] = [ {}, node_json ]
            else
              new_jvar[:children][a[6]][:children][a[5]][:children][a[4]][:children][a[3]][:children][a[2]][:children][a[1]][:children] << node_json
            end
          end

        when 8  # when tree height is nine, like with 129 leaves

          if a[0] == 0
            if new_jvar[:children][a[7]][:children][a[6]][:children][a[5]][:children][a[4]][:children][a[3]][:children][a[2]][:children][a[1]][:children].blank?
              new_jvar[:children][a[7]][:children][a[6]][:children][a[5]][:children][a[4]][:children][a[3]][:children][a[2]][:children][a[1]][:children] = [node_json]
            else
              new_jvar[:children][a[7]][:children][a[6]][:children][a[5]][:children][a[4]][:children][a[3]][:children][a[2]][:children][a[1]][:children][0] = node_json
            end
          else
            if new_jvar[:children][a[7]][:children][a[6]][:children][a[5]][:children][a[4]][:children][a[3]][:children][a[2]][:children][a[1]][:children].blank?
              new_jvar[:children][a[7]][:children][a[6]][:children][a[5]][:children][a[4]][:children][a[3]][:children][a[2]][:children][a[1]][:children] = [ {}, node_json ]
            else
              new_jvar[:children][a[7]][:children][a[6]][:children][a[5]][:children][a[4]][:children][a[3]][:children][a[2]][:children][a[1]][:children] << node_json
            end
          end

        when 9 # when tree height is ten, 257 leaves or more
          if a[0] == 0
            if new_jvar[:children][a[8]][:children][a[7]][:children][a[6]][:children][a[5]][:children][a[4]][:children][a[3]][:children][a[2]][:children][a[1]][:children].blank?
              new_jvar[:children][a[8]][:children][a[7]][:children][a[6]][:children][a[5]][:children][a[4]][:children][a[3]][:children][a[2]][:children][a[1]][:children] = [node_json]
            else
              new_jvar[:children][a[8]][:children][a[7]][:children][a[6]][:children][a[5]][:children][a[4]][:children][a[3]][:children][a[2]][:children][a[1]][:children][0] = node_json
            end
          else
            if new_jvar[:children][a[8]][:children][a[7]][:children][a[6]][:children][a[5]][:children][a[4]][:children][a[3]][:children][a[2]][:children][a[1]][:children].blank?
              new_jvar[:children][a[8]][:children][a[7]][:children][a[6]][:children][a[5]][:children][a[4]][:children][a[3]][:children][a[2]][:children][a[1]][:children] = [ {}, node_json ]
            else
              new_jvar[:children][a[8]][:children][a[7]][:children][a[6]][:children][a[5]][:children][a[4]][:children][a[3]][:children][a[2]][:children][a[1]][:children] << node_json
            end
          end

        when 10 # when tree height is eleven, 513 leaves or more
          if a[0] == 0
            if new_jvar[:children][a[9]][:children][a[8]][:children][a[7]][:children][a[6]][:children][a[5]][:children][a[4]][:children][a[3]][:children][a[2]][:children][a[1]][:children].blank?
              new_jvar[:children][a[9]][:children][a[8]][:children][a[7]][:children][a[6]][:children][a[5]][:children][a[4]][:children][a[3]][:children][a[2]][:children][a[1]][:children] = [node_json]
            else
              new_jvar[:children][a[9]][:children][a[8]][:children][a[7]][:children][a[6]][:children][a[5]][:children][a[4]][:children][a[3]][:children][a[2]][:children][a[1]][:children][0] = node_json
            end
          else
            if new_jvar[:children][a[9]][:children][a[8]][:children][a[7]][:children][a[6]][:children][a[5]][:children][a[4]][:children][a[3]][:children][a[2]][:children][a[1]][:children].blank?
              new_jvar[:children][a[9]][:children][a[8]][:children][a[7]][:children][a[6]][:children][a[5]][:children][a[4]][:children][a[3]][:children][a[2]][:children][a[1]][:children] = [ {}, node_json ]
            else
              new_jvar[:children][a[9]][:children][a[8]][:children][a[7]][:children][a[6]][:children][a[5]][:children][a[4]][:children][a[3]][:children][a[2]][:children][a[1]][:children] << node_json
            end
          end

        when 11 # when tree height is twelve, 1 025 leaves or more
          if a[0] == 0
            if new_jvar[:children][a[10]][:children][a[9]][:children][a[8]][:children][a[7]][:children][a[6]][:children][a[5]][:children][a[4]][:children][a[3]][:children][a[2]][:children][a[1]][:children].blank?
              new_jvar[:children][a[10]][:children][a[9]][:children][a[8]][:children][a[7]][:children][a[6]][:children][a[5]][:children][a[4]][:children][a[3]][:children][a[2]][:children][a[1]][:children] = [node_json]
            else
              new_jvar[:children][a[10]][:children][a[9]][:children][a[8]][:children][a[7]][:children][a[6]][:children][a[5]][:children][a[4]][:children][a[3]][:children][a[2]][:children][a[1]][:children][0] = node_json
            end
          else
            if new_jvar[:children][a[10]][:children][a[9]][:children][a[8]][:children][a[7]][:children][a[6]][:children][a[5]][:children][a[4]][:children][a[3]][:children][a[2]][:children][a[1]][:children].blank?
              new_jvar[:children][a[10]][:children][a[9]][:children][a[8]][:children][a[7]][:children][a[6]][:children][a[5]][:children][a[4]][:children][a[3]][:children][a[2]][:children][a[1]][:children] = [ {}, node_json ]
            else
              new_jvar[:children][a[10]][:children][a[9]][:children][a[8]][:children][a[7]][:children][a[6]][:children][a[5]][:children][a[4]][:children][a[3]][:children][a[2]][:children][a[1]][:children] << node_json
            end
          end

        when 12 # when tree height is thirteen, 2 049 leaves or more
          if a[0] == 0
            if new_jvar[:children][a[11]][:children][a[10]][:children][a[9]][:children][a[8]][:children][a[7]][:children][a[6]][:children][a[5]][:children][a[4]][:children][a[3]][:children][a[2]][:children][a[1]][:children].blank?
              new_jvar[:children][a[11]][:children][a[10]][:children][a[9]][:children][a[8]][:children][a[7]][:children][a[6]][:children][a[5]][:children][a[4]][:children][a[3]][:children][a[2]][:children][a[1]][:children] = [node_json]
            else
              new_jvar[:children][a[11]][:children][a[10]][:children][a[9]][:children][a[8]][:children][a[7]][:children][a[6]][:children][a[5]][:children][a[4]][:children][a[3]][:children][a[2]][:children][a[1]][:children][0] = node_json
            end
          else
            if new_jvar[:children][a[11]][:children][a[10]][:children][a[9]][:children][a[8]][:children][a[7]][:children][a[6]][:children][a[5]][:children][a[4]][:children][a[3]][:children][a[2]][:children][a[1]][:children].blank?
              new_jvar[:children][a[11]][:children][a[10]][:children][a[9]][:children][a[8]][:children][a[7]][:children][a[6]][:children][a[5]][:children][a[4]][:children][a[3]][:children][a[2]][:children][a[1]][:children] = [ {}, node_json ]
            else
              new_jvar[:children][a[11]][:children][a[10]][:children][a[9]][:children][a[8]][:children][a[7]][:children][a[6]][:children][a[5]][:children][a[4]][:children][a[3]][:children][a[2]][:children][a[1]][:children] << node_json
            end
          end

        when 13 # when tree height is fourteen, 4 097 leaves or more
          if a[0] == 0
            if new_jvar[:children][a[12]][:children][a[11]][:children][a[10]][:children][a[9]][:children][a[8]][:children][a[7]][:children][a[6]][:children][a[5]][:children][a[4]][:children][a[3]][:children][a[2]][:children][a[1]][:children].blank?
              new_jvar[:children][a[12]][:children][a[11]][:children][a[10]][:children][a[9]][:children][a[8]][:children][a[7]][:children][a[6]][:children][a[5]][:children][a[4]][:children][a[3]][:children][a[2]][:children][a[1]][:children] = [node_json]
            else
              new_jvar[:children][a[12]][:children][a[11]][:children][a[10]][:children][a[9]][:children][a[8]][:children][a[7]][:children][a[6]][:children][a[5]][:children][a[4]][:children][a[3]][:children][a[2]][:children][a[1]][:children][0] = node_json
            end
          else
            if new_jvar[:children][a[12]][:children][a[11]][:children][a[10]][:children][a[9]][:children][a[8]][:children][a[7]][:children][a[6]][:children][a[5]][:children][a[4]][:children][a[3]][:children][a[2]][:children][a[1]][:children].blank?
              new_jvar[:children][a[12]][:children][a[11]][:children][a[10]][:children][a[9]][:children][a[8]][:children][a[7]][:children][a[6]][:children][a[5]][:children][a[4]][:children][a[3]][:children][a[2]][:children][a[1]][:children] = [ {}, node_json ]
            else
              new_jvar[:children][a[12]][:children][a[11]][:children][a[10]][:children][a[9]][:children][a[8]][:children][a[7]][:children][a[6]][:children][a[5]][:children][a[4]][:children][a[3]][:children][a[2]][:children][a[1]][:children] << node_json
            end
          end

        when 14 # when tree height is fifteen, 8 193 leaves or more
          if a[0] == 0
            if new_jvar[:children][a[13]][:children][a[12]][:children][a[11]][:children][a[10]][:children][a[9]][:children][a[8]][:children][a[7]][:children][a[6]][:children][a[5]][:children][a[4]][:children][a[3]][:children][a[2]][:children][a[1]][:children].blank?
              new_jvar[:children][a[13]][:children][a[12]][:children][a[11]][:children][a[10]][:children][a[9]][:children][a[8]][:children][a[7]][:children][a[6]][:children][a[5]][:children][a[4]][:children][a[3]][:children][a[2]][:children][a[1]][:children] = [node_json]
            else
              new_jvar[:children][a[13]][:children][a[12]][:children][a[11]][:children][a[10]][:children][a[9]][:children][a[8]][:children][a[7]][:children][a[6]][:children][a[5]][:children][a[4]][:children][a[3]][:children][a[2]][:children][a[1]][:children][0] = node_json
            end
          else
            if new_jvar[:children][a[13]][:children][a[12]][:children][a[11]][:children][a[10]][:children][a[9]][:children][a[8]][:children][a[7]][:children][a[6]][:children][a[5]][:children][a[4]][:children][a[3]][:children][a[2]][:children][a[1]][:children].blank?
              new_jvar[:children][a[13]][:children][a[12]][:children][a[11]][:children][a[10]][:children][a[9]][:children][a[8]][:children][a[7]][:children][a[6]][:children][a[5]][:children][a[4]][:children][a[3]][:children][a[2]][:children][a[1]][:children] = [ {}, node_json ]
            else
              new_jvar[:children][a[13]][:children][a[12]][:children][a[11]][:children][a[10]][:children][a[9]][:children][a[8]][:children][a[7]][:children][a[6]][:children][a[5]][:children][a[4]][:children][a[3]][:children][a[2]][:children][a[1]][:children] << node_json
            end
          end

        when 15 # when tree height is sixteen, 16 385 leaves or more
          if a[0] == 0
            if new_jvar[:children][a[14]][:children][a[13]][:children][a[12]][:children][a[11]][:children][a[10]][:children][a[9]][:children][a[8]][:children][a[7]][:children][a[6]][:children][a[5]][:children][a[4]][:children][a[3]][:children][a[2]][:children][a[1]][:children].blank?
              new_jvar[:children][a[14]][:children][a[13]][:children][a[12]][:children][a[11]][:children][a[10]][:children][a[9]][:children][a[8]][:children][a[7]][:children][a[6]][:children][a[5]][:children][a[4]][:children][a[3]][:children][a[2]][:children][a[1]][:children] = [node_json]
            else
              new_jvar[:children][a[14]][:children][a[13]][:children][a[12]][:children][a[11]][:children][a[10]][:children][a[9]][:children][a[8]][:children][a[7]][:children][a[6]][:children][a[5]][:children][a[4]][:children][a[3]][:children][a[2]][:children][a[1]][:children][0] = node_json
            end
          else
            if new_jvar[:children][a[14]][:children][a[13]][:children][a[12]][:children][a[11]][:children][a[10]][:children][a[9]][:children][a[8]][:children][a[7]][:children][a[6]][:children][a[5]][:children][a[4]][:children][a[3]][:children][a[2]][:children][a[1]][:children].blank?
              new_jvar[:children][a[14]][:children][a[13]][:children][a[12]][:children][a[11]][:children][a[10]][:children][a[9]][:children][a[8]][:children][a[7]][:children][a[6]][:children][a[5]][:children][a[4]][:children][a[3]][:children][a[2]][:children][a[1]][:children] = [ {}, node_json ]
            else
              new_jvar[:children][a[14]][:children][a[13]][:children][a[12]][:children][a[11]][:children][a[10]][:children][a[9]][:children][a[8]][:children][a[7]][:children][a[6]][:children][a[5]][:children][a[4]][:children][a[3]][:children][a[2]][:children][a[1]][:children] << node_json
            end
          end

        else
          puts "I will deal with this node later."
        end
        new_jvar

      end # of method update_json(jvar,node_json)
      
    
  
end # of module