class TreesController < ApplicationController


  def index
    @trees = Tree.all
  end
  
  def new
    @tree = Tree.new
  end
  
  def create
      @tree = Tree.new(tree_params)
      

      if @tree.save
 
        Resque.enqueue(TreeWorker,@tree.id) # launch new job in app/jobs/tree_worker.rb

        file_name = "account_list_" + @tree.id.to_s + ".csv"

        redirect_to trees_path, notice: "Tree was successfully created: processing file #{file_name}."
       else
         render action: 'new'
      end
  end

  def edit
    @tree = Tree.find(params[:id])
  end

  def update
    @tree = Tree.find(params[:id])
    if @tree.update_attributes(tree_params)
      redirect_to @tree
    else
      render :edit
    end
  end

  def show
    @tree = Tree.find(params[:id])
    
    @nodes = @tree.nodes
    @leaf_nodes = @tree.leaf_nodes
    
    unless @nodes
      respond_to do |format|
        flash[:success] = "Processing file: please refresh the page until it is finished processing."
        format.html { render action: 'show'}
      end
    end
    
  end
  
  def destroy
    @tree = Tree.find_by_id(params[:id])
    @tree.destroy
    
    @leaf_nodes = @tree.leaf_nodes
    if @leaf_nodes
      @leaf_nodes.each do |leaf_node|
        leaf_node.destroy
      end
    end
      
    @nodes = @tree.nodes
    if @nodes
      @nodes.each do |node|
        node.destroy
      end
    end
    
    @trees = Tree.all
    redirect_to trees_path, notice: 'Tree was successfully deleted.'
  end
  
  def display 
    @tree = Tree.find_by_id(params[:id])
    
    s3 = AWS::S3.new(
    :access_key_id     => Figaro.env.access_key_id,
        :secret_access_key => Figaro.env.secret_access_key
    )
    
    bucket = s3.buckets[Figaro.env.s3_bucket]
    object = bucket.objects["tree_#{@tree.id}.json"]

    @json_tree = object.read

  end
  
  
  def upload_json
    @tree = Tree.find(params[:id])
    puts params
  end
  
  
  def download_json
    @tree = Tree.find(params[:id])
    
    s3 = AWS::S3.new(
    :access_key_id     => Figaro.env.access_key_id,
        :secret_access_key => Figaro.env.secret_access_key
    )
    
    bucket = s3.buckets[Figaro.env.s3_bucket]
    object = bucket.objects["tree_#{@tree.id}.json"]
    
    send_data object.read, filename: "#{@tree.name}.json", type: "application/json", disposition: 'attachment', stream: 'true', buffer_size: '4096'
    
  end



  private
 
     def tree_params
       params.require(:tree).permit(:avatar, :roll, :json_file, :name, :depth, :height, :count, :error_count)
       #params.require(:tree).permit(leaf_nodes_attributes: [:nonce, :credit, :name, :tree_id])
       #params.require(:tree).permit(nodes_attributes: [:left, :right,:height, :sum, :hash, :tree_id])
     end

end