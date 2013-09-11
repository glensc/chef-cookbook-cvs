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

require "chef/resource/scm"

class Chef
  class Resource
    class Cvs < Chef::Resource::Scm

      def initialize(name, run_context=nil)
        super
        @cvsroot = ''
        @resource_name = :cvs
        @provider = Chef::Provider::Cvs
      end

      def cvsroot(arg=nil)
        @cvsroot, arg = nil, nil if arg == false
        set_or_return(
          :cvsroot,
          arg,
          :kind_of => String
        )
      end
    end
  end
end
