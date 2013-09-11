#
# Cookbook Name:: cvs
#
# Copyright 2013, Elan Ruusamäe
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

require 'chef/log'
require 'chef/provider'
require 'chef/mixin/command'
require 'fileutils'

class Chef
  class Provider
    class Cvs < Chef::Provider

      include Chef::Mixin::Command

      def whyrun_supported?
        true
      end

      def load_current_resource
        @current_resource = Chef::Resource::Cvs.new(@new_resource.name)
      end

      def define_resource_requirements
        requirements.assert(:all_actions) do |a|
          # Make sure the parent dir exists, or else fail.
          # for why run, print a message explaining the potential error.
          a.assertion { ::File.directory?(parent_directory) }
          a.failure_message(Chef::Exceptions::MissingParentDirectory, 
            "Cannot checkout #{@new_resource} to #{@new_resource.destination}, the enclosing directory #{parent_directory} does not exist")
          a.whyrun("Directory #{parent_directory} does not exist, assuming it would have been created")
        end
      end

      def action_checkout
        if target_dir_non_existent_or_empty?
          converge_by("perform checkout of #{@new_resource.repository} into #{@new_resource.destination}") do
            run_command(run_options(:command => checkout_command, :cwd => parent_directory))
          end
        else
          Chef::Log.debug "#{@new_resource} checkout destination #{@new_resource.destination} already exists or is a non-empty directory - nothing to do"
        end
      end

      # TODO: check if target is same cvs module as we are checking out!
      def action_sync
        assert_target_directory_valid!
        if ::File.exist?(::File.join(@new_resource.destination, "CVS"))
          Chef::Log.debug "#{@new_resource} update"
          converge_by("sync #{@new_resource.destination} from #{@new_resource.repository}") do
            run_command(run_options(:command => sync_command))
            Chef::Log.info "#{@new_resource} updated"
          end 
        else
          action_checkout
        end
      end
      
      def action_export
        if target_dir_non_existent_or_empty?
          converge_by("export #{@new_resource.repository} into #{@new_resource.destination}") do
            run_command(run_options(:command => export_command, :cwd => parent_directory))
          end
        else
          Chef::Log.debug "#{@new_resource} export destination #{@new_resource.destination} already exists or is a non-empty directory - nothing to do"
        end
      end

      private

      def checkout_command
        subdir = ::File.basename(@new_resource.destination)
        c = scm :checkout,
            "-d", subdir,
            "-r", @new_resource.revision,
            @new_resource.repository
        Chef::Log.info "#{@new_resource} checked out #{@new_resource.repository} at revision #{@new_resource.revision} to #{@new_resource.destination}"
        c
      end

      def sync_command
        c = scm :update,
          "-r#{@new_resource.revision}"
        Chef::Log.debug "#{@new_resource} updated working copy #{@new_resource.destination} to revision #{@new_resource.revision}"
        c
      end

      def export_command
        subdir = ::File.basename(@new_resource.destination)
        c = scm :export,
            "-d", subdir,
            "-r", @new_resource.revision,
            @new_resource.repository
        Chef::Log.info "#{@new_resource} exported #{@new_resource.repository} at revision #{@new_resource.revision} to #{@new_resource.destination}"
        c
      end

      def run_options(run_opts={})
        run_opts[:user] = @new_resource.user if @new_resource.user
        run_opts[:group] = @new_resource.group if @new_resource.group
        run_opts[:environment] = {"CVS_SSH" => @new_resource.ssh_wrapper} if @new_resource.ssh_wrapper
        run_opts[:cwd] ||= @new_resource.destination
        run_opts
      end

      def verbose
        "-q"
      end

      def scm(*args)
        ['cvs', verbose, "-d", @new_resource.cvsroot, *args].compact.join(" ")
      end

      def parent_directory
        ::File.dirname(@new_resource.destination)
      end

      def target_dir_non_existent_or_empty?
        !::File.exist?(@new_resource.destination) || Dir.entries(@new_resource.destination).sort == ['.','..']
      end

      def assert_target_directory_valid!
        target_parent_directory = ::File.dirname(@new_resource.destination)
        unless ::File.directory?(target_parent_directory)
          msg = "Cannot clone #{@new_resource} to #{@new_resource.destination}, the enclosing directory #{target_parent_directory} does not exist"
          raise Chef::Exceptions::MissingParentDirectory, msg
        end
      end
    end
  end
end
