# Changelog for CVS Cookbook

## 0.4.0 - 2018-03-22

* Chef-13 related fixes

## 0.3.0 - 2017-04-19

* `node['cvs']['cvskeeper']['exclude']` is globs. backwards incompatible change.

## 0.2.3 - 2017-04-19

* Add `node['cvs']['cvskeeper']['updated_resources']` attribute

## 0.2.2 - 2015-12-02

* Make `CVS_RSH` configurable via `node['cvs']['cvswrapper']` attribute

## 0.2.1 - 2014-11-10

* Set umask to 0002 (3e4d38a5)
* Catch exceptions to avoid internal errors locking out the node (bb419d8)
* Allow excluding paths not to track via `node['cvs']['cvskeeper']['exclude']` (6c610d4)

## 0.2.0 - 2014-02-16

* Add `cvskeeper` recipe

## 0.1.2 - 2014-01-29

* Rubocop fixes, adding to travis

## 0.1.1 - 2013-09-30

* Add `node['cvs']['package']` attribute

## 0.1.0 - 2013-09-11

* Initial release of CVS cookbook
