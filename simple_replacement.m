function simple_replacement(varargin)

if nargin == 0
    [file, path, ~] = uigetfile('*.py');
    pythonfile = [path file];
elseif nargin == 1
    pythonfile = varargin{1};
end
    
fid = fopen(pythonfile);

fidout = fopen([pythonfile '.m'], 'w');

tline = fgets(fid);
while ischar(tline)
    processed = processing_line(tline);
    
    
    fprintf(fidout, '%s', processed); % this way the string will not get escaped.
    
    
    
    
    
    
    tline = fgets(fid);
end

fclose(fidout);
fclose(fid);

% pass 2

fulltext = fileread([pythonfile '.m']);

fulltext = contextual_processing(fulltext);

fidout = fopen([pythonfile '.m'], 'w');
fprintf(fidout, '%s', fulltext);
fclose(fidout);

% pass 3

indentation_analysis([pythonfile '.m']);


end


function processed = processing_line(tline)

processed = tline;

% remove import line
if strfind(processed, 'import ') == 1
    processed = '';
end

% remove ending colon

strtoremovecolon = {...
    'def ', 'if ', 'for '...
    };

if contains_any(processed, strtoremovecolon)
    pos_last_colon = strfind(processed, ':');
    if ~isempty(pos_last_colon)
        pos_last_colon = pos_last_colon(end);
        processed = [processed(1:pos_last_colon-1) processed(pos_last_colon+1:end)];
    end
end


% keyword replacement

strtoreplace = {...
    '#','%';
    'def ','function ';
    'np.','';
    '[','(';
    ']',')';
    '**','^';
    ' in ',' = ';
    };


for i = 1:size(strtoreplace, 1)
    processed = strrep(processed, strtoreplace{i, 1}, strtoreplace{i, 2});
end



% add ;

strtonotaddsemicolon = {...
    'def ', 'if ', 'for ', 'while ', 'return ', 'function ',...
    };

if ~contains_any(processed, strtonotaddsemicolon)

    pos_before_comment = strfind(processed, '%');
    if isempty(pos_before_comment)
        pos_before_comment = length(processed) - 1;
    end

    firstpos = pos_before_comment(1);
    while firstpos > 1
        if processed(firstpos - 1) == ' '
            firstpos = firstpos - 1;
        else
            break;
        end
    end
    
    if firstpos > 1
        processed = [processed(1:firstpos-1) ';' processed(firstpos:end)];
    end

end


% range processing

rangeposs = strfind(processed, 'range');
for rangepos = rangeposs
    
    rangeparampos = rangepos + 5; % jump over 'range' itself
    while rangeparampos < length(processed)
        if processed(rangeparampos) == ' '
            rangeparampos = rangeparampos + 1;
        else
            break;
        end
    end
    
    if processed(rangeparampos) ~= '('
        continue;
    end
    commapos = strfind(processed(rangeparampos+1:end), ',');
    commapos = commapos(1) + rangeparampos;
    closingparenthesispos = strfind(processed(rangeparampos+1:end), ')');
    closingparenthesispos = closingparenthesispos(1) + rangeparampos;
    
    rangenum1 = processed(rangeparampos+1:commapos-1);
    rangenum2 = processed(commapos+1:closingparenthesispos-1);
    
    % range is exclusive:
    if ~isempty(str2num(rangenum2))
        rangenum2 = num2str(str2num(rangenum2) - 1);
    else
        % may be expressions
        rangenum2 = [rangenum2 ' - 1'];
    end
    
    processed = [processed(1:rangepos-1) rangenum1 ':' rangenum2 processed(closingparenthesispos+1:end)];
        
end
    

end

function result = contains_any(inputstr, strlist)

result = false;
for i=1:length(strlist)
    result = result | ~isempty(strfind(inputstr, strlist{i}));
end

end

function textout = contextual_processing(textin)

textout = textin;

% return values

returnpos = strfind(textout, 'return ');
while ~isempty(returnpos)
    returnpos = returnpos(1);
    
    prevnewline = strfind(textout(1:returnpos-1), sprintf('\n')); % need sprintf \n otherwise it would not escape
    prevnewline = prevnewline(end);
    nextnewline = strfind(textout(returnpos:end), sprintf('\n')); % ignore comments after return for now
    nextnewline = nextnewline(1) + returnpos - 1;
    
    % to do a better way to handle this
    if textout(prevnewline - 1) == sprintf('\r')
        prevnewline = prevnewline + 1;
    end
    if textout(nextnewline - 1) == sprintf('\r')
        nextnewline = nextnewline - 1;
    end
    
    
    functionpos = strfind(textout(1:returnpos-1), 'function ');
    functionpos = functionpos(end); % the last occurance
    
    % save before remove
    returnval = textout(returnpos+7:nextnewline-1);
    % remove return
    textout = [textout(1:prevnewline) textout(nextnewline:end)];
    
    textout = [textout(1:functionpos + 8) '[ ' returnval ' ] = ' textout(functionpos + 9:end)];
    
    
    
    returnpos = strfind(textout, 'return ');

end


end

function indentation_analysis(filename)

inferred_indentation = 0;
indentation_char = [];

fid = fopen(filename);

fidout = fopen([filename '.temp'], 'w');


previous_indents = 0;
current_indents = 0;

tline = fgets(fid);
while ischar(tline)
    
    if inferred_indentation == 0
        if tline(1) == sprintf('\t')
            inferred_indentation = 1; % meaning one tab
            indentation_char = sprintf('\t');
            indents = indents + 1;
        elseif tline(1) == ' '
            indentation_char = ' ';
            % how many? 
            for c = tline
                if c == ' '
                    inferred_indentation = inferred_indentation + 1;
                else
                    break;
                end
            end
%             current_indents = 1;
            previous_indents = 1;
        end
        
        % before move on
        fprintf(fidout, '%s', tline);
        tline = fgets(fid);
        continue;
    end
    
    
    current_indents = 0;     
    for c = tline
        if c == indentation_char
            current_indents = current_indents + 1;
        else
            if c == sprintf('\r') || c == sprintf('\n')
                current_indents = -1; % empty line, invalidates the value;
            end
            break;
        end
    end
    
    if current_indents ~= -1
        
        if indentation_char == ' '
            current_indents = current_indents / inferred_indentation;
        end





        if current_indents < previous_indents
            % add end's
            
            for i = previous_indents - current_indents - 1:-1:0
            
                endline = [repmat(indentation_char, [1, inferred_indentation * (current_indents + i)]) 'end'];
                fprintf(fidout, '%s\n', endline);
                
            end
        end
        
        
        previous_indents = current_indents;

    end
    
    fprintf(fidout, '%s', tline);

    
    
    tline = fgets(fid);
end

fclose(fidout);
fclose(fid);

delete(filename);
copyfile([filename '.temp'], filename);
delete([filename '.temp']);

end

% TODO: replace strfind with a custom one that does not search in string literal