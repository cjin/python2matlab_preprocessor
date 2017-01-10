function separate_functions(varargin)

if nargin == 0
    [file, path, ~] = uigetfile('*.py.m');
    py2mfile = [path file];
    outputdir = uigetdir;

elseif nargin == 1
    py2mfile = varargin{1};
    outputdir = uigetdir;
elseif nargin == 2
    py2mfile = varargin{1};
    outputdir = varargin{2};
end

[~,mainname,~] = fileparts(py2mfile(1:end-5));
mkdir([outputdir '/' mainname]);

fulltext = fileread(py2mfile);

funcposs = strfind(fulltext, 'function ');

for i = 1:length(funcposs)
    funcpos = funcposs(i);
    
    parenthesispos = strfind(fulltext(funcpos:end), '(');
    parenthesispos = parenthesispos(1) + funcpos - 1;
    nextnewlinepos = strfind(fulltext(funcpos:end), sprintf('\n'));
    nextnewlinepos = nextnewlinepos(1) + funcpos - 1;
    
    if fulltext(nextnewlinepos - 1) == sprintf('\r')
        nextnewlinepos = nextnewlinepos - 1;
    end
    
    nextdelimpos = min(parenthesispos, nextnewlinepos);
    
    % find funcname beginning
    spacepos = strfind(fulltext(1:nextdelimpos-1), ' ');
    spacepos = spacepos(end);
    equalpos = strfind(fulltext(1:nextdelimpos-1), '=');
    equalpos = equalpos(end);
    funcnamebeginpos = max(spacepos, equalpos) + 1;
    
    funcname = fulltext(funcnamebeginpos:nextdelimpos-1);
    
    if i == length(funcposs)
        funccontent = fulltext(funcpos:end);
    else
        funccontent = fulltext(funcpos:funcposs(i+1)-1);
    end
    
    fid = fopen([outputdir '/' mainname '/' funcname '.m'], 'w');
    fprintf(fid, '%s', funccontent);
    fclose(fid);

end

