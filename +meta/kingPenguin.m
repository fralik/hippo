
% Read in Excel worksheet generated by addCellNums and add rate maps and count
% maps. Saves result in mat file.
%
%   USAGE
%       meta.kingPenguin
%
%   SEE ALSO
%       meta.addCellNums meta.emperorPenguin
%
% Written by BRK 2015

function kingPenguin

tic

%% get globals
global hippoGlobe
if isempty(hippoGlobe.inputFile)
    startup
end

%% read excel file to analyze
[filename,filepath] = uigetfile({'*.xlsx','*.xls'},'Select Excel workbook');
if ~filename; return; end
excelFile = fullfile(filepath,filename);
sheetName = inputdlg('Worksheet name:','',1,{'masterCellNums'});
if isempty(sheetName); return; end
[~,~,raw] = xlsread(excelFile,sheetName{1});

%% set output location
excelFolder = uigetdir('','Choose folder for the mat file output');
if ~excelFolder; return; end
matName = inputdlg('Mat file name:','',1,{'masterMat'});
if isempty(matName); return; end
matFile = fullfile(excelFolder,matName{1});

%% get column headers and folder names
for iLabel = 1:size(raw,2)
    labels{iLabel} = raw{1,iLabel};
end
labels{end+1} = 'Rate map';
labels{end+1} = 'Count map';
dataInput = raw(2:end,:);  
folders = unique(dataInput(:,1)');

%% rate map settings
prompt={'Smoothing (# of bins)','Spatial bin width (cm)','Mininum occupancy'};
name='Map settings';
numlines=1;
defaultanswer={num2str(hippoGlobe.smoothing),num2str(hippoGlobe.binWidth),'0'};
Answers = inputdlg(prompt,name,numlines,defaultanswer,'on');
if isempty(Answers); return; end;
smooth = str2double(Answers{1});
binWidth = str2double(Answers{2});
minTime = str2double(Answers{3});

%% compute stats for each folder
for iFolder = 1:length(folders)
    
    display(sprintf('Folder %d of %d',iFolder,length(folders)))
    
    %% load data
    folderInds = find(strcmpi(dataInput(:,1),folders{1,iFolder}));
    writeInputBNT(hippoGlobe.inputFile,folders{1,iFolder},hippoGlobe.arena,hippoGlobe.clusterFormat)
    data.loadSessions(hippoGlobe.inputFile);    
    
    %% get positions, spikes, map, and rates
    pos = data.getPositions('average','off','speedFilter',hippoGlobe.posSpeedFilter);
    posAve = data.getPositions('speedFilter',hippoGlobe.posSpeedFilter);
    save(fullfile(folders{1,iFolder},'posCleanScaled.mat'),'pos','posAve');
    posT = posAve(:,1);
    posX = posAve(:,2);
    posY = posAve(:,3);
    
    numClusters = length(folderInds);
    for iCluster = 1:numClusters
        
        display(sprintf('Cluster %d of %d',iCluster,numClusters))
        
        %% calculate maps
        tetrode = cell2mat(dataInput(folderInds(iCluster),strcmpi('tetrode',labels)));
        cluster = cell2mat(dataInput(folderInds(iCluster),strcmpi('cluster',labels)));
        spikes = data.getSpikeTimes([tetrode,cluster]);
        map = analyses.map([posT posX posY],spikes,'smooth',smooth,'binWidth',binWidth,'minTime',minTime,'limits',hippoGlobe.mapLimits);
        
        %% store data
        dataInput{folderInds(iCluster),strcmpi('rate map',labels)} = map.z;
        dataInput{folderInds(iCluster),strcmpi('count map',labels)} = map.count;
        
    end
    
end

dataOutput = dataInput;

%% add mouse IDs using filenames
labels(end+1) = {'Mouse ID'};
for iFolder = 1:size(dataOutput,1)
    filename = dataOutput{iFolder,strcmpi('folder',labels)};
    startIdx = strfind(filename,'BK');
    if ~isempty(startIdx)
        mouseID = filename(startIdx:startIdx+4);
    else
        startIdx = strfind(filename,'CML');
        mouseID = filename(startIdx:startIdx+3);
    end
    dataOutput(iFolder,strcmpi('mouse id',labels)) = {mouseID};
end

%% add unique experiment numbers
Answer = questdlg('Do all experiments have the same number of sessions?');
% set flag to be able to break out
flag = 1;
while flag
    if strcmpi(Answer,'Yes')
        labels(end+1) = {'Exp num'};
        folderList = folders';
        try     % maybe we already have sessions
            seshNames = unique(dataOutput(:,strcmpi('session',labels)));
            numSesh = numel(seshNames);
        catch   % or maybe we don't
            Answer2 = inputdlg('How many sessions are in each experiment?','',1,{'3'});
            if ~isempty(Answer2)
                numSesh = str2double(Answer2{1});
            else   % abort
                warning('Not adding experiment numbers because you didn''t answer.');
                labels = labels(1:end-1);
                flag = 0;
            end
        end
        % add exp nums here
        numList = [];
        for iExp = 1:length(folderList)/numSesh
            numList = [numList; repmat(iExp,numSesh,1)];
        end
        folderList(:,2) = num2cell(numList);
        temp_data = dataOutput;
        for iFolder = 1:size(temp_data,1)
            temp_data(iFolder,strcmpi('exp num',labels)) = folderList(strcmpi(temp_data{iFolder,1},folderList(:,1)),2);
        end
        dataOutput = temp_data;
        flag = 0;
    else
        flag = 0;
    end
end

%% convert some numbers into strings to make things easier later 
for iFolder = 1:size(dataOutput,1)
    dataOutput{iFolder,strcmpi('cell num',labels)} = num2str(dataOutput{iFolder,strcmpi('cell num',labels)});
    dataOutput{iFolder,strcmpi('quality',labels)} = num2str(dataOutput{iFolder,strcmpi('quality',labels)});
end
if sum(strcmpi('exp num',labels))
    for iFolder = 1:size(dataOutput,1)
        dataOutput{iFolder,strcmpi('exp num',labels)} = num2str(dataOutput{iFolder,strcmpi('exp num',labels)});
    end
end
if sum(strcmpi('dose',labels))
    for iFolder = 1:size(dataOutput,1)
        dataOutput{iFolder,strcmpi('dose',labels)} = num2str(dataOutput{iFolder,strcmpi('dose',labels)});
    end
end
if sum(strcmpi('cno num',labels))
    for iFolder = 1:size(dataOutput,1)
        if isnan(dataOutput{iFolder,strcmpi('cno num',labels)})
            dataOutput{iFolder,strcmpi('cno num',labels)} = 0;
        end
    end
end

%% save output
save(matFile,'dataOutput','labels');

toc

% load handel
% sound(y(1:7000),Fs)