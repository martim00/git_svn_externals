git svn externals
======

Introduction
----------

This script can be used to clone an SVN repository with externals.

Usage
----------

1. Run 'perl git_svn_externals.pl' in the root of git-svn cloned repository
2. profit :)

Features
----------

1. Script fetches all svn externals specified recursively.
2. On subseqent runs script fetches new externals and updates existing ones.
3. Svn externals with revision specified will be updated to apropriate
   revisions everytime the revision specified changes in svn repository.
4. Running 'git svn dcommit' is possible due to all fetched svn externals
   being excluded from the "root" git repository.

Known problems
----------

1. If your external references a revision, it have to reference an existing revision 
   or the script will not work. 
   For example, if in the svn log of your external the revisions 1 and 7 appear, 
   you can't reference revision 5 in the external. In this case you should reference 
   revsion 1.

Author
----------

Dmitry Sushko <Dmitry.Sushko@yahoo.com>

Ricardo Pescuma Domenecci