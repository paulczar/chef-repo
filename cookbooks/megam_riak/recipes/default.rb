#
# Author:: Seth Thomas (<sthomas@basho.com>)
# Cookbook Name:: megam_riak
# Recipe:: default
#
# Copyright (c) 2013 Basho Technologies, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
include_recipe "ulimit"

node.set["myroute53"]["name"] = "#{node.name}"

if node['megam_domain']
node.set["myroute53"]["zone"] = "#{node['megam_domain']}"
else
node.set["myroute53"]["zone"] = "megam.co."
end

include_recipe "megam_route53"


#Cookbook to parse the json which is in s3. Json contains the cookbook dependencies.
include_recipe "megam_deps"

include_recipe "megam_ciakka"

include_recipe "ganglia::riak"


#node.set ['riak']['args']['-name'] = "riak@#{node["myroute53"]["name"]}.#{node["myroute53"]["zone"]}"

version_str = "#{node['riak']['package']['version']['major']}.#{node['riak']['package']['version']['minor']}"
base_uri = "#{node['riak']['package']['url']}/#{version_str}/#{version_str}.#{node['riak']['package']['version']['incremental']}/"
base_filename = "riak-#{version_str}.#{node['riak']['package']['version']['incremental']}"

case node['platform']
when "fedora", "centos", "redhat"
  node.set['riak']['config']['riak_core']['platform_lib_dir'] = "/usr/lib64/riak".to_erl_string if node['kernel']['machine'] == 'x86_64'
  machines = {"x86_64" => "x86_64", "i386" => "i386", "i686" => "i686"}
  base_uri = "#{base_uri}#{node['platform']}/#{node['platform_version'].to_i}/"
  package_file = "#{base_filename}-#{node['riak']['package']['version']['build']}.fc#{node['platform_version'].to_i}.#{node['kernel']['machine']}.rpm"
  package_uri = base_uri + package_file
  package_name = package_file.split("[-_]\d+\.").first
end

if node['riak']['package']['local_package'] == true
  package_file = node['riak']['package']['local_package']

  cookbook_file "#{Chef::Config[:file_cache_path]}/#{package_file}" do
    source package_file
    owner "root"
    mode 0644
    not_if(File.exists?("#{Chef::Config[:file_cache_path]}/#{package_file}") && Digest::SHA256.file("#{Chef::Config[:file_cache_path]}/#{package_file}").hexdigest == checksum_val)
  end
else
  case node['platform']
  when "ubuntu", "debian"

execute "WGET RIAK DEB PACKAGE " do
  cwd "/home/ubuntu"  
  user "ubuntu"
  group "ubuntu"
  command "wget http://s3.amazonaws.com/downloads.basho.com/riak/1.4/1.4.0/ubuntu/precise/riak_1.4.0-1_amd64.deb"
end 

execute "DEPACKAGE RIAK DEB " do
  cwd "/home/ubuntu"  
  user "ubuntu"
  group "ubuntu"
  command "sudo dpkg -i riak_1.4.0-1_amd64.deb"
end

  when "centos", "rhel"
    include_recipe "yum"

    yum_key "RPM-GPG-KEY-basho" do
      url "http://yum.basho.com/gpg/RPM-GPG-KEY-basho"
      action :add
    end

    yum_repository "basho" do
      repo_name "basho"
      description "Basho Stable Repo"
      url "http://yum.basho.com/el/#{node['platform_version'].to_i}/products/x86_64/"
      key "RPM-GPG-KEY-basho"
      action :add
    end

    package "riak" do
      action :install
    end

  when "fedora"

    remote_file "#{Chef::Config[:file_cache_path]}/#{package_file}" do
      source package_uri
      owner "root"
      mode 0644
      not_if(File.exists?("#{Chef::Config[:file_cache_path]}/#{package_file}") && Digest::SHA256.file("#{Chef::Config[:file_cache_path]}/#{package_file}").hexdigest == node['riak']['package']['checksum']['local'])
    end

    package package_name do
      source "#{Chef::Config[:file_cache_path]}/#{package_file}"
      action :install
    end
  end
end

file "#{node['riak']['package']['config_dir']}/app.config" do
  content Eth::Config.new(node['riak']['config'].to_hash).pp
  owner "root"
  mode 0644
  notifies :restart, "service[riak]"
end

file "#{node['riak']['package']['config_dir']}/vm.args" do
  content Eth::Args.new(node['riak']['args'].to_hash).pp
  owner "root"
  mode 0644
  notifies :restart, "service[riak]"
end

user_ulimit "riak" do
  filehandle_limit node['riak']['limits']['nofile']
end

node['riak']['patches'].each do |patch|
  cookbook_file "#{node['riak']['config']['riak_core']['platform_lib_dir'].gsub(/__string_/,'')}/lib/basho-patches/#{patch}" do
    source patch
    owner "root"
    mode 0644
    checksum
    notifies :restart, "service[riak]"
  end
end

service "riak" do
  supports :start => true, :stop => true, :restart => true
  action [ :enable, :start ]
end


if node['riak']['cluster']['node_name']

execute "Start riak" do
  cwd "/home/ubuntu"  
  user "ubuntu"
  group "ubuntu"
  command "riak start"
end

execute "Execute Cluster node" do
  cwd "/home/ubuntu"  
  user "ubuntu"
  group "ubuntu"
  command "riak-admin cluster join riak@#{node['riak']['cluster']['node_name']}"
end 

execute "Execute Cluster plan" do
  cwd "/home/ubuntu"  
  user "ubuntu"
  group "ubuntu"
  command "riak-admin cluster plan"
end 

execute "Execute Cluster commit" do
  cwd "/home/ubuntu"  
  user "ubuntu"
  group "ubuntu"
  command "riak-admin cluster commit"
end 

end
