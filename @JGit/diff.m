function diff(varargin)
%JGIT.DIFF Show changes between commits, commit and working tree, etc.
%   JGIT.DIFF opens the MATLAB editor and, if DIFFTOOL is set as true, the
%   MATLAB Visual Comparison Tool.
%   JGIT.DIFF(PARAMETER,VALUE,...) uses any combination of the following
%   PARAMETER, VALUE pairs.
%   'cached' <logical> [false] View the changes you staged for the next
%       commit.
%   'previous' <char> '' The previous state.
%   'updated' <char> '' The updated state.
%   'path' <char|cellstr> ['']  Limit the diff to the named path(s).
%   'showNameAndStatusOnly' <logical> [false] return only names and status of changed files.
%   'contextLines' <integer> [3] Set number of context lines instead of the usual three.
%   'srcPrefix' <char> ['a/'] Set the given source prefix instead of "a/".
%   'destPrefix' <char> ['b/'] Set the given destination prefix instead of "b/".
%   'showProgress' <logical> [false] Show progress.
%   'difftool' <logical> [false] Show diff in MATLAB visual comparison tool.
%   'gitDir' <char> [PWD] Applies to the repository in specified folder.
%
%   For more information see also
%   <a href="https://www.kernel.org/pub/software/scm/git/docs/git-diff.html">Git Diff Documentation</a>
%   <a href="http://download.eclipse.org/jgit/docs/latest/apidocs/org/eclipse/jgit/api/DiffCommand.html">JGit Git API Class DifftCommand</a>
%
%   Example:
%       JGIT.DIFF('previous','master',updated','feature', ...
%           'path',{'file1','file2},'difftool',true) % compare file1 and file2
%           from master to feature branch in MATLAB visual comparison tool.
%       JGIT.DIFF('chached',true) % compare HEAD to staged files.
%
%   See also JGIT, MERGE, LOG, STATUS
%
%   Version 0.4 - Dragonfly Release
%   2013-06-04 Mark Mikofski
%   <a href="http://poquitopicante.blogspot.com">poquitopicante.blogspot.com</a>

%% constants
% TODO: move these to JGIT as Constant properties so JGIT.COMMIT can use too
TMP = getenv('tmp');
DIFF_DIR = 'jgitdiff';
TMP_DIFF_DIR = fullfile(TMP,DIFF_DIR);
%% check inputs
p = inputParser;
p.addParamValue('cached',false,@(x)validateattributes(x,{'logical'},{'scalar'}))
p.addParamValue('previous','',@(x)validateattributes(x,{'char'},{'row'}))
p.addParamValue('updated','',@(x)validateattributes(x,{'char'},{'row'}))
p.addParamValue('path','',@(x)validatepaths(x))
p.addParamValue('showNameAndStatusOnly',false,@(x)validateattributes(x,{'logical'},{'scalar'}))
p.addParamValue('contextLines',0,@(x)validateattributes(x,{'numeric'},{'integer', ...
    'nonnegative','scalar'}))
p.addParamValue('srcPrefix','',@(x)validateattributes(x,{'char'},{'row'}))
p.addParamValue('destPrefix','',@(x)validateattributes(x,{'char'},{'row'}))
p.addParamValue('showProgress',false,@(x)validateattributes(x,{'logical'},{'scalar'}))
p.addParamValue('difftool',false,@(x)validateattributes(x,{'logical'},{'scalar'}))
p.addParamValue('gitDir',pwd,@(x)validateattributes(x,{'char'},{'row'}))
p.parse(varargin{:})
gitAPI = JGit.getGitAPI(p.Results.gitDir);
diffCMD = gitAPI.diff;
%% flush jgit diff tmp dir
% TODO: move these to JGIT as Static method so JGIT.COMMIT can use too
if exist(TMP_DIFF_DIR,'dir')==7
    [status, message, messageid]= rmdir(TMP_DIFF_DIR,'s');
    assert(status,messageid,message)
end
mkdir(TMP_DIFF_DIR)
%% repository
repo = gitAPI.getRepository;
reader = repo.newObjectReader;
%% set old tree
if ~isempty(p.Results.previous)
    oldTreeId = repo.resolve([p.Results.previous,'^{tree}']);
    oldTree = org.eclipse.jgit.treewalk.CanonicalTreeParser([],reader,oldTreeId);
    diffCMD.setOldTree(oldTree);
end
%% set new tree
if ~isempty(p.Results.updated)
    newTreeId = repo.resolve([p.Results.updated,'^{tree}']);
    newTree = org.eclipse.jgit.treewalk.CanonicalTreeParser([],reader,newTreeId);
    diffCMD.setNewTree(newTree);
end
%% set cached flag
if p.Results.cached
    diffCMD.setCached(true);
end
%% set paths
if ~isempty(p.Results.path)
    pathfilter = org.eclipse.jgit.treewalk.filter.PathFilterGroup;
    treefilter = pathfilter.createFromStrings(p.Results.path);
    diffCMD.setPathFilter(treefilter);
end
%% set Outpit stream
% TODO: wrap with buffered writer or string builder for very large files
DIFF_FILE = fullfile(TMP_DIFF_DIR,[p.Results.previous,p.Results.updated,'.diff']);
diffFileOS = java.io.FileOutputStream(DIFF_FILE);
diffCMD.setOutputStream(diffFileOS);
%% show progress
if p.Results.showProgress
    diffCMD.setProgressMonitor(com.mikofski.jgit4matlab.MATLABProgressMonitor);
end
%% show name and status only
if p.Results.showNameAndStatusOnly
    diffCMD.setShowNameAndStatusOnly(true);
end
%% set source prefix
if ~isempty(p.Results.srcPrefix)
    diffCMD.setSourcePrefix(p.Results.srcPrefix);
end
%% set destination prefix
if ~isempty(p.Results.destPrefix)
    diffCMD.setDestinationPrefix(p.Results.destPrefix);
end
%% set number of context lines
if p.Results.contextLines>0
    diffCMD.setContextLines(uint16(p.Results.contextLines));
end
%% call
diffs = diffCMD.call;
if ~diffs.isEmpty
    edit(DIFF_FILE);
end
diffFileOS.close
%% show MATLAB visual comparison tool
if p.Results.difftool
    ndiffs = diffs.size;
    for n = 1:ndiffs
        d = diffs.get(n-1);
        oldpath = char(d.getOldPath);
        newpath = char(d.getNewPath);
        if strcmp('/dev/null',oldpath)
            oldpath = 'dev:null.m';
        end
        if strcmp('/dev/null',newpath)
            newpath = 'dev:null.m';
        end
        oldAbbrev = d.getOldId;
        newAbbrev = d.getNewId;
        oldId = oldAbbrev.toObjectId;
        newId = newAbbrev.toObjectId;
        oldSHA = char(oldAbbrev.name);
        newSHA = char(newAbbrev.name);
        OLDFILE = fullfile(TMP_DIFF_DIR,['[',oldSHA(1:8),']-',strrep(oldpath,'/','.')]);
        NEWFILE = fullfile(TMP_DIFF_DIR,['[',newSHA(1:8),']-',strrep(newpath,'/','.')]);
        oldFileOS = java.io.FileOutputStream(OLDFILE);
        newFileOS = java.io.FileOutputStream(NEWFILE);
        if repo.hasObject(oldId)
            oldObjLoader = repo.open(oldId);
            oldObjLoader.copyTo(oldFileOS);
        elseif ~oldId.equals(oldId.zeroId)
            copyFromWorkingTree(p.Results.gitDir, oldpath, oldFileOS)
        end
        if repo.hasObject(newId)
            newObjLoader = repo.open(newId);
            newObjLoader.copyTo(newFileOS);
        elseif ~newId.equals(newId.zeroId)
            copyFromWorkingTree(p.Results.gitDir, newpath, newFileOS)
        end
        oldFileOS.close
        newFileOS.close
        visdiff(OLDFILE,NEWFILE)
    end
end
end

function tf = validatepaths(paths)
if ~iscellstr(paths)
    validateattributes(paths,{'char'},{'row'})
end
tf = true;
end

function copyFromWorkingTree(gitDir, path, fileOS)
fileIS = java.io.FileInputStream(fullfile(gitDir, path));
inReader = java.io.InputStreamReader(fileIS);
inBuffer = java.io.BufferedReader(inReader);
outWriter = java.io.OutputStreamWriter(fileOS);
outBuffer = java.io.BufferedWriter(outWriter);
l = inBuffer.readLine;
while l~=-1
    outBuffer.append(l);
    outBuffer.newLine;
    l = inBuffer.readLine;
end
inBuffer.close
outBuffer.close
inReader.close
outWriter.close
end
