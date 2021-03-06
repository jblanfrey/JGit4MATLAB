function status(gitDir,fid,amend)
%JGIT.STATUS Return the status of the repository.
%   JGIT.STATUS(GITDIR) Specify the folder in which Git Repo resides.
%   JGIT.STATUS(GITDIR,FID) Output status to file identifier, FID.
%   JGIT.STATUS(GITDIR,FID,AMEND) Add "Initial commit" text to status.
%
%   For more information see also
%   <a href="https://www.kernel.org/pub/software/scm/git/docs/git-status.html">Git Status Documentation</a>
%   <a href="http://download.eclipse.org/jgit/docs/latest/apidocs/org/eclipse/jgit/api/StatusCommand.html">JGit Git API Class StatusCommand</a>
%
%   Example:
%       JGIT.STATUS
%
%   See also JGIT
%
%   Version 0.4 - Dragonfly Release
%   2013-06-04 Mark Mikofski
%   <a href="http://poquitopicante.blogspot.com">poquitopicante.blogspot.com</a>

%% Check inputs
if nargin<1
    gitDir = pwd;
end
if nargin<2
    fid = 1;
end
if nargin<3
    amend = false;
end
gitAPI = JGit.getGitAPI(gitDir);
%% call
statusCall = gitAPI.status.call;
%% display status
fmtStr = '# On branch %s\n';
fprintf(fid,fmtStr,char(gitAPI.getRepository.getBranch));
% if amended add "Initial commit" to status message
if amend
    fprintf(fid,'#\n# Initial commit\n#\n');
end
if statusCall.isClean
    %% status message if clean
    fprintf('nothing to commit, working directory clean\n')
else
    %% staged fils
    added = statusCall.getAdded;
    changed = statusCall.getChanged;
    removed = statusCall.getRemoved;
    if ~added.isEmpty || ~changed.isEmpty || ~removed.isEmpty
        fprintf(fid,[ ...
            '# Changes to be committed:\n', ...
            '#   (use "git reset HEAD <file>..." to unstage)\n', ...
            '#\n']);
        if fid==1
            fmtStr = '#       <a href="matlab: edit(''%s'')">modified:   %s</a>\n';
        else
            fmtStr = '#       modified:   %s\n';
        end
        iter = changed.iterator;
        for n = 1:changed.size
            str = {iter.next};
            if fid==1;str = {str{1},str{1}};end
            fprintf(fid,fmtStr,str{:});
        end
        if fid==1
            fmtStr = '#       <a href="matlab: edit(''%s'')">new file:   %s</a>\n';
        else
            fmtStr = '#       new file:   %s\n';
        end
        iter = added.iterator;
        for n = 1:added.size
            str = {iter.next};
            if fid==1;str = {str{1},str{1}};end
            fprintf(fid,fmtStr,str{:});
        end
        if fid==1
            fmtStr = '#       <a href="matlab: edit(''%s'')">deleted:   %s</a>\n';
        else
            fmtStr = '#       deleted:    %s\n';
        end
        iter = removed.iterator;
        for n = 1:removed.size
            str = {iter.next};
            if fid==1;str = {str{1},str{1}};end
            fprintf(fid,fmtStr,str{:});
        end
        fprintf(fid,'#\n');
    end
    %% tracked but not staged
    modified = statusCall.getModified;
    missing = statusCall.getMissing;
    if ~modified.isEmpty || ~missing.isEmpty
        fprintf(fid,'# Changes not staged for commit:\n');
        if ~missing.isEmpty
            fprintf(fid,'#   (use "git add/rm <file>..." to update what will be committed)\n');
        else
            fprintf(fid,'#   (use "git add <file>..." to update what will be committed)\n');
        end
        fprintf(fid,[ ...
            '#   (use "git checkout -- <file>..." to discard changes in working directory)\n', ...
            '#\n']);
        if fid==1,fid = 2;end
        fmtStr = '#       modified:   %s\n';
        iter = modified.iterator;
        for n = 1:modified.size
            fprintf(fid,fmtStr,iter.next);
        end
        fmtStr = '#       deleted:    %s\n';
        iter = missing.iterator;
        for n = 1:missing.size
            fprintf(fid,fmtStr,iter.next);
        end
        if fid==2,fid = 1;end
        fprintf(fid,'#\n');
    end
    %% untracked and/or ignored
    untracked = statusCall.getUntracked;
    ignored = statusCall.getIgnoredNotInIndex;
    ignoreFlag = false(untracked.size,1);
    iter = untracked.iterator;
    for n = 1:untracked.size
        ignoreFlag(n) = ignored.contains(iter.next);
    end
    if ~untracked.isEmpty && ~all(ignoreFlag)
        fprintf(fid,[ ...
            '# Untracked files:\n', ...
            '#   (use "git add <file>..." to include in what will be committed)\n', ...
            '#\n']);
        fmtStr = '#       %s\n';
        if fid==1,fid = 2;end
        iter = untracked.iterator;
        for n = 1:untracked.size
            if ~ignoreFlag
                fprintf(2,fmtStr,iter.next);
            end
        end
        if fid==2,fid = 1;end
        fprintf(fid,'#\n');
    end
    fprintf(fid,'# no changes added to commit (use "git add" and/or "git commit -a")\n');
end
end
