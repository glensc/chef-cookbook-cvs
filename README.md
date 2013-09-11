CVS Cookbook
============

Provides LWRP for CVS Repositories

Requirements
------------
A `cvs` client installed


Resources and Providers
=======================

`cvs`
--------

The `cvs` LWRP can be used to checkout repositories with CVS

    cvs "/tmp/deploy" do
      cvsroot "/usr/local/cvs"
      repository "CVSROOT"
      action :checkout
    end

LWRP attributes:

* `cvsroot`
    * Repository root aka $CVSROOT variable.
* `repository`
    * Module inside CVSROOT
* `action`
    * Action to run, `:checkout`, `:sync`, `:export`

Contributing
------------

1. Fork the repository on Github
2. Create a named feature branch (like `add_component_x`)
3. Write you change
4. Write tests for your change (if applicable)
5. Run the tests, ensuring they all pass
6. Submit a Pull Request using Github

License and Author
==================

Author:: Elan Ruusamäe (<glen@delfi.ee>)

Copyright 2013, Elan Ruusamäe

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
