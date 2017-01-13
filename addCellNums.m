
% Read in Excel worksheet generated by emperorPenguin and add unique cell
% numbers. Will attempt to add session names if they don't exist already.
% Saves result in new Excel sheet in same workbook.
%
%   USAGE
%       addCellNums
%
%   SEE ALSO
%       emperorPenguin kingPenguinSelect
%
% Written by BRK 2015

function addCellNums

%% read excel file to analyze
[filename filepath] = uigetfile({'*.xlsx','*.xls'},'Select Excel workbook');
if ~filename; return; end
excelFile = fullfile(filepath,filename);
sheetName = inputdlg('Worksheet name:','',1,{'master'});
if isempty(sheetName); return; end
[~,~,raw] = xlsread(excelFile,sheetName{1});

%% set output location
newSheetName = inputdlg('New worksheet name:','',1,{'masterCellNums'});
if isempty(newSheetName); return; end
newSheetName = newSheetName{1};

%% update labels
clear labels compList
for iLabel = 1:size(raw,2)
    labels{iLabel} = raw{1,iLabel};
end
labels{end+1} = 'Cell num';
raw(1,1:end+1) = labels;

%% create column of first session names for comparison, and extract session names if needed
if sum(strcmpi('session',labels))   % we already have sessions
    sessions = unique(raw(2:end,strcmpi('session',labels)),'stable');
    for iRow = 2:size(raw,1)
        compList{iRow,1} = sessions{1};
    end
else    % need to extract sessions
    warning(['Extracting session names could fail miserably depending on your directory names. ' ...
        'If this happens to you, manually add a column with session names before running this script.']);
    labels{end+1} = 'Session';
    raw(1,1:end+1) = labels;
    for iRow = 2:size(raw,1)
%         splits = regexp(raw{iRow,strcmpi('folder',labels)},'\','split');
%         raw{iRow,strcmpi('session',labels)} = splits{end}(1);
%         if iRow == 2
%             firstSessionName = splits{end}(1);
%         end
        ind = strfind(raw{iRow,strcmpi('folder',labels)},'BL2');
        if isempty(ind)
            ind2 = strfind(raw{iRow,strcmpi('folder',labels)},'CNO');
            if isempty(ind2)
                ind3 = strfind(raw{iRow,strcmpi('folder',labels)},'BL');
                raw{iRow,strcmpi('session',labels)} = 'BL';
                if iRow == 2
                    firstSessionName = 'BL';
                end
            else
                raw{iRow,strcmpi('session',labels)} = 'CNO';
                if iRow == 2
                    firstSessionName = 'CNO';
                end
            end
        else
            raw{iRow,strcmpi('session',labels)} = 'BL2';
            if iRow == 2
                firstSessionName = 'BL2';
            end
        end
        compList{iRow,1} = firstSessionName;
    end
end

%% create unique cell numbers
firstSeshInds = cellfun(@strcmpi,raw(:,strcmpi('session',labels)),compList);
numTotalClusters = sum(firstSeshInds);
cellNum = 0;
for iRow = 2:size(raw,1)
    if firstSeshInds(iRow)
        cellNum = cellNum + 1;
    end
    raw{iRow,strcmpi('cell num',labels)} = cellNum;
end

%% append to dataset and write excel file
dataWithCellNums = raw;
xlswrite(excelFile,dataWithCellNums,newSheetName);
