# Changelog for CVS Cookbook

## 0.2.3:

* Add `node['cvs']['cvskeeper']['updated_resources']` attribute

## 0.2.2:

* Make `CVS_RSH` configurable via `node['cvs']['cvswrapper']` attribute

## 0.2.1:

* Set umask to 0002 (3e4d38a5)
* Catch exceptions to avoid internal errors locking out the node (bb419d8)
* Allow excluding paths not to track via `node['cvs']['cvskeeper']['exclude']` (6c610d4)

## 0.2.0:

* Add `cvskeeper` recipe

## 0.1.2:

* Rubocop fixes, adding to travis

## 0.1.1:

* Add `node['cvs']['package']` attribute

## 0.1.0:

* Initial release of CVS cookbook
