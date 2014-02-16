# setup "cvskeeper" (based on etckeeper)

include_recipe 'chef_handler::default'

cookbook_file "#{node.chef_handler.handler_path}/cvskeeper-handler.rb" do
  source 'cvskeeper-handler.rb'
end

file '/etc/chef/client.d/cvskeeper-handler.rb' do
  content <<-EOQ
require '#{node.chef_handler.handler_path}/cvskeeper-handler.rb'
event_handlers [] unless event_handlers
event_handlers << Cvskeeper::EventHandler.new
EOQ
end
