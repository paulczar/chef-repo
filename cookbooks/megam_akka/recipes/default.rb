#
# Cookbook Name:: megam_akka
# Recipe:: default
#
# Copyright 2013, Megam Systems
#
# All rights reserved - Do Not Redistribute
#


include_recipe "megam_sandbox"
=begin
node.set["myroute53"]["name"] = "#{node.name}"

if node['megam_domain']
node.set["myroute53"]["zone"] = "#{node['megam_domain']}"
else
node.set["myroute53"]["zone"] = "megam.co"
end

include_recipe "megam_route53"
=end

include_recipe "apt"

node.set['logstash']['beaver']['inputs'] = [ "/var/log/akka.sys.log" ]
#node.set['logstash']['key'] = "#{node.name}.#{node["myroute53"]["zone"]}"
node.set['logstash']['redis_url'] = "redis1.megam.co.in"
include_recipe "megam_logstash::beaver"



package "openjdk-7-jdk" do
        action :install
end

package "zip unzip" do
        action :install
end

package "tar" do
        action :install
end

#node.set["deps"]["node_key"] = "#{node.name}.#{node["myroute53"]["zone"]}"
node.set["deps"]["node_key"] = "oriental.megam.co"
include_recipe "megam_deps"

=begin
gem_package "knife-ec2" do
  action :install
end
=end

scm_ext = File.extname(node["megam_deps"]["predefs"]["scm"])
file_name = File.basename(node["megam_deps"]["predefs"]["scm"])
dir = File.basename(file_name, '.*')

directory "/usr/local/share/#{dir}" do
  owner "root"
  group "root"
  mode "0755"
  action :create
end

case scm_ext
when ".git"
include_recipe "git"
execute "Clone git " do
  cwd node["sandbox"]["home"]  
  user node["sandbox"]["user"]
  group node["sandbox"]["user"]
  command "git clone #{node["megam_deps"]["predefs"]["scm"]}"
end


directory "#{node["sandbox"]["home"]}/bin" do
  owner node["sandbox"]["user"]
  group node["sandbox"]["user"]
  mode "0755"
  action :create
end

execute "add PATH for bin sbt" do
  cwd node["sandbox"]["home"]  
  user node["sandbox"]["user"]
  group node["sandbox"]["user"]
  command "echo \"PATH=$PATH:$HOME/bin\" >> #{node["sandbox"]["home"]}/.bashrc"
end

execute "Refresh bashrc" do
  cwd node["sandbox"]["home"]  
  user node["sandbox"]["user"]
  group node["sandbox"]["user"]
  command "source .bashrc"
end

remote_file "#{node["sandbox"]["home"]}/bin/sbt-launch.jar" do
  source node["akka"]["sbt"]["jar"]
  mode "0755"
   owner node["sandbox"]["user"]
  group node["sandbox"]["user"]
  checksum "08da002l" 
end

template "#{node["sandbox"]["home"]}/bin/sbt" do
  source "sbt.erb"
  owner node["sandbox"]["user"]
  group node["sandbox"]["user"]
  mode "0755"
end


execute "Stage play project" do
  cwd "#{node["sandbox"]["home"]}/#{dir}"  
  user node["sandbox"]["user"]
  group node["sandbox"]["user"]
  command "sbt clean compile stage dist"
end


execute "Copy zip to /usr/local/share" do
  cwd "#{node["sandbox"]["home"]}/#{dir}"  
  user "root"
  group "root"
  command "sudo cp #{node["sandbox"]["home"]}/#{dir}/dist/*.zip /usr/local/share/#{dir} "
end

execute "Unzip dist content " do
  cwd "/usr/local/share/#{dir}"  
  user "root"
  group "root"
  command "sudo unzip *.zip"
end

execute "Chmod for start script " do
  cwd "/usr/local/share/#{dir}/*" #DONT KNOW THE DIR NAME 
  user "root"
  group "root"
  command "sudo chmod 755 start"
end


when ".zip"

remote_file "/usr/local/share/#{dir}/#{file_name}" do
  source node["megam_deps"]["predefs"]["scm"]
  mode "0755"
  owner "root"
  group "root"
end

execute "Unzip dist content " do
  cwd "/usr/local/share/#{dir}"  
  user "root"
  group "root"
  command "sudo unzip *.zip"
end

node.set["akka"]["dir"]["script"] = "/usr/local/share/#{dir}/*"
node.set["akka"]["file"]["script"] = "start"

execute "Chmod for start script " do
  cwd "/usr/local/share/#{dir}/#{dir}" #DONT KNOW THE DIR NAME 
  user "root"
  group "root"
  command "sudo chmod 755 start"
end

when ".tar"

remote_file "/usr/local/share/#{dir}/#{file_name}" do
  source node["megam_deps"]["predefs"]["scm"]
  mode "0755"
  owner "root"
  group "root"
end

execute "Untar tar file " do
  cwd "/usr/local/share/#{dir}"  
  user "root"
  group "root"
  command "sudo tar -xvzf #{file_name}"
end

node.set['akka']['script']['cmd'] = "/usr/local/share/#{dir}/#{dir}/bin/start org.megam.akka.CloApp"

when ".gz"

file_name = File.basename(file_name, '.*')
dir = File.basename(file_name, '.*')

directory "/usr/local/share/#{dir}" do
  owner "root"
  group "root"
  mode "0755"
  action :create
end

remote_file "/usr/local/share/#{dir}/#{file_name}" do
  source node["megam_deps"]["predefs"]["scm"]
  mode "0755"
  owner "root"
  group "root"
end

execute "Untar tar file " do
  cwd "/usr/local/share/#{dir}"  
  user "root"
  group "root"
  command "sudo tar -xvzf #{file_name}"
end

node.set['akka']['script']['cmd'] = "/usr/local/share/#{dir}/#{dir}/bin/start org.megam.akka.CloApp"


when ".deb"

remote_file "#{node["sandbox"]["home"]}/#{file_name}" do
  source node["megam_deps"]["predefs"]["scm"]
  mode "0755"
  owner node["sandbox"]["user"]
  group node["sandbox"]["user"]
end

execute "Depackage deb file" do
  cwd node["sandbox"]["home"]  
  user node["sandbox"]["user"]
  group node["sandbox"]["user"]
  command "sudo dpkg -i #{file_name}"
end

else
remote_file "#{node["sandbox"]["home"]}/megam_herk.deb" do
  source node['akka']['deb']
  owner node['akka']['user']
  group node['akka']['user']
  mode node['akka']['mode']
end

execute "Depackage megam akka" do
  cwd node["sandbox"]["home"]  
  user node['akka']['user']
  group node['akka']['user']
  command node['akka']['dpkg']
end
end #case

template node['akka']['init']['conf'] do
  source node['akka']['template']['conf']
  owner node['akka']['user']
  group node['akka']['user']
  mode node['akka']['mode']
end

execute "Start Akka" do
  cwd node["sandbox"]["home"]  
  user node['akka']['user']
  group node['akka']['user']
  command node['akka']['start']
end

