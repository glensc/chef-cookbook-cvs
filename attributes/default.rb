#
# Cookbook Name:: cvs
# Attributes:: default
#
# Copyright 2013-2017, Elan Ruusamäe
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

# Name of package providing CVS client
# Possible values: cvs, cvsnt
default['cvs']['package'] = 'cvs'

# cvskeeper: path to CVS_RSH
default['cvs']['cvswrapper'] = nil

# paths that cvskeeper should not track
default['cvs']['cvskeeper']['exclude'] = %w[/etc/mtab /etc/ldap.secret]

# whether to include updated_resources details in commit messages
default['cvs']['cvskeeper']['updated_resources'] = false
