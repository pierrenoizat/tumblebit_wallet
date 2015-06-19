# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rake db:seed (or created alongside the db with db:setup).
#
# Examples:
#
#   cities = City.create([{ name: 'Chicago' }, { name: 'Copenhagen' }])
#   Mayor.create(name: 'Emanuel', city: cities.first)

Post.delete_all

Post.create(
  id: 1,
  title: "My Very First Post",
  published_at: Time.now - 1.day,
  body: 
  %Q{### There Is Something You Should Know!

  This is my very first post using markdown!

  How do you like it?  I learned this from [RichOnRails.com](http://richonrails.com/articles/rendering-markdown-with-redcarpet)!}
)

Post.create(
  id: 2,
  title: "My Second Post",
  published_at: Time.now,
  body: 
  %Q{### My List of Things To Do!

  Here is the list of things I wish to do!
  
  * write more posts
  * write even more posts
  * write even more posts!}
)

Post.create(
  id: 3,
  title: "About",
  published_at: Time.now,
  body: 
  %Q{### About binary hash trees
    

  The root path of each node can be followed on the tree graph: a zero points to the top node while a one points to the bottom node.
  
  If there is only a single parent, then the root path includes a zero to represent the link between the node and its single parent.
  
  For instance, in a tree of height 5, a root path like "0000" represents the top edge of the tree graph linking the root to the top leaf node.
  
  The position of the leaf nodes are randomized so that nothing can be inferred about the accounts from their respective position in the tree graph.
  
  Tree graphs are drawn using the [D3 javascript library](http://d3js.org)}
)