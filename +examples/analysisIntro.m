
% This tutorial will show you how to take the output from kingPenguin and extract meaningful information.
% The main goals are to learn how to do the following:
%
%   1. Load data.
%   2. Extract information about the experimental design (e.g. number of sessions).
%   3. Filter the data to only include those cells which meet certain criteria (e.g. good quality CA1 place cells).
%   4. Extract/calculate a measure for each of these cells (e.g. mean firing rate).
%   5. Compare results between experimental groups (e.g. different CNO doses).
%   6. Plot results in informative ways (e.g. bar plot vs beehive plot) that are visually pleasing.
%   7. Check data for normality and run statistical tests to compare results between groups.
%   8. Save figures and numerical results for later use.
%
% There are many other little things throughout that should be useful in the future. Some examples are:
% 
%   - Displaying text in the command window or in a figure with the help of sprintf.
%   - Using combinations of numel, sum, unique, all, and isnan to count your data.
%   - Padding arrays with nans and later removing these unused rows/columns.
%   - Nested for loops. Which levels (e.g. dose, session) do you need, and which order should they be in?
%   - Managing n-dimensional arrays with the help of squeeze and arrayfun.
%   - Accessing figure objects with findobj and changing their properties
%
%   USAGE
%       analysisIntro
%
%   SEE ALSO
%       kingPenguin emperorPenguin
%
% Written by BRK 2017


% function analysisIntro
% NB: uncomment the previous line (remove %) to run this script as a function, which means all variables will only
%     be available locally (during execution of the function). this prevents your workspace from being cluttered
%     with variables that you probably don't need/want stored in memory.

%% load the mat file which is output from kingPenguin
display('Loading data...')
tic   % start a stopwatch
load('N:\benjamka\masterMatDose.mat')
display(sprintf('Loaded data in %.2f sec.\n',toc))   % toc displays the elapsed time from the stopwatch


%% extract some information about your experiments
sessions = extract.cols(dataOutput,labels,'session');
% NB:   this is the first example of filtering your data. read the function help for extract.cols and extract.rows
%       and try some examples to understand what is happening. here we simply extract the column of the data
%       array with the label 'session'. later we will also require that certain conditions be met.

sessions = unique(sessions,'stable');
% NB:   we use the argument 'stable' here to return session names in the order they are found 
%       in the data array (i.e. {'BL','CNO','BL2'}), which is the default behavior.
%       use 'sorted' to return {'BL','BL2','CNO'} instead.

numSesh = numel(sessions);

% we can display the information extracted as we go
display(sprintf('We have %d sessions: %s\n',numSesh,strjoin(sessions)))


%% filter to include only cells with good cluster quality

% you need to specify here which quality judgments mean 'bad' and 'off'
badQ = '3';
offQ = '4';
cleanedData = extract.cleanUpQuality(dataOutput,labels,sessions,numSesh,badQ,offQ);
% NB: here we assign the filtered data to a new variable 'cleanedData' for clarity. this will waste memory
%     and get confusing if done too many times, so you can overwrite by calling the output 'dataOutput' instead.

% let's display how many much of the data we're filtering out at each step
numIn = numel(unique(extract.cols(dataOutput,labels,'cell num')));       % this line finds the number of unique cell numbers in 'dataOutput'
numOut = numel(unique(extract.cols(cleanedData,labels,'cell num')));
display(sprintf('We just threw out %d of %d cells (%.0f%%). We have %d good quality cells.', ...
    numIn-numOut, ...
    numIn, ...
    100*((numIn-numOut)/numIn), ...
    numOut))


%% filter to include only CA1 cells with CNO doses of 0, 0.5, 15 mg/kg
CA1subset = extract.rows(cleanedData,labels,'keep','region','CA1','dose',{'0','0.5','15'});

numIn = numel(unique(extract.cols(cleanedData,labels,'cell num')));
numOut = numel(unique(extract.cols(CA1subset,labels,'cell num')));
display(sprintf('We just threw out %d of %d cells (%.0f%%). We have %d CA1 cells with 0, 0.5, or 15 mg/kg CNO.', ...
    numIn-numOut, ...
    numIn, ...
    100*((numIn-numOut)/numIn), ...
    numOut))

%% filter for putative excitatory cells (i.e. mean rate under 7 Hz in first session)

% first extract the cell numbers that meet this criteria, then include ALL data from these cells
cellsToKeep = extract.cols(CA1subset,labels,'cell num','session',sessions{1},'mean rate','<',7);
CA1exc = extract.rows(CA1subset,labels,'keep','cell num',cellsToKeep);

% NB:  if you try to do this step in one line (seen below), you will only get data from the first session,
%      because extract.rows and extract.cols have the condition that ALL specified criteria are met
% CA1exc = extract.rows(CA1subset,labels,'keep','session',sessions{1},'mean rate','<',7);

numIn = numel(unique(extract.cols(CA1subset,labels,'cell num')));
numOut = numel(unique(extract.cols(CA1exc,labels,'cell num')));
display(sprintf('We just threw out %d of %d cells (%.0f%%). We have %d excitatory cells.', ...
    numIn-numOut, ...
    numIn, ...
    100*((numIn-numOut)/numIn), ...
    numOut))


%% filter for place cells (i.e. mean rate >= 0.1 Hz and at least 1 place field in EITHER of the first 2 sessions)
placeInBL = extract.cols(CA1exc,labels,'cell num','session',sessions{1},'mean rate','>=',0.1,'number of fields','>=',1);
placeInCNO = extract.cols(CA1exc,labels,'cell num','session',sessions{2},'mean rate','>=',0.1,'number of fields','>=',1);
cellsToKeep = unique([placeInBL; placeInCNO]);
% NB:  how would you change the previous line to include cells which meet the criteria in BOTH sessions?
CA1place = extract.rows(CA1exc,labels,'keep','cell num',cellsToKeep);

numIn = numel(unique(extract.cols(CA1exc,labels,'cell num')));
numOut = numel(unique(extract.cols(CA1place,labels,'cell num')));
display(sprintf('We just threw out %d of %d cells (%.0f%%). We have %d place cells.\n', ...
    numIn-numOut, ...
    numIn, ...
    100*((numIn-numOut)/numIn), ...
    numOut))


%% extract mean firing rate

% initialize a storage array with nans to save processing time and to avoid filling in missing values with zeros
doseNames = unique(extract.cols(CA1place,labels,'dose'));
numDoses = numel(doseNames);
dataStore = nan(1000,numDoses,numSesh);   % dimensions are: clusters X doses X session
% NB:   since we don't know ahead of time the number of clusters for a given dose in a given session,
%       pick a number that is definitely too big (e.g. 1000). we'll remove the extra rows at the end.

for iDose = 1:numDoses   % loop through each CNO dose
    
    doseData = extract.rows(CA1place,labels,'keep','dose',doseNames{iDose});
    clusterNums = unique(extract.cols(doseData,labels,'cell num'),'stable');
    numClusters = numel(clusterNums);

    for iCluster = 1:numClusters   % loop through each cluster
        
        for iSession = 1:numSesh   % loop through each session
            
            quality = extract.cols(doseData,labels,'quality','cell num',clusterNums{iCluster},'session',sessions{iSession});
            if ~strcmpi(quality,badQ)   % check that cluster quality is not bad
                meanRate = extract.cols(doseData,labels,'mean rate','cell num',clusterNums{iCluster},'session',sessions{iSession});
                dataStore(iCluster,iDose,iSession) = meanRate;
            end
            
        end   % session
        
    end   % cluster
    
end   % dose


%% clean up the data a bit

% separate the data by dose
con = squeeze(dataStore(:,1,:));
low = squeeze(dataStore(:,2,:));
high = squeeze(dataStore(:,3,:));

% remove rows at the bottom that are all nans
con(all(arrayfun(@isnan,con)'),:) = [];
low(all(arrayfun(@isnan,low)'),:) = [];
high(all(arrayfun(@isnan,high)'),:) = [];


%% compute rate difference scores between BL and CNO sessions
rdCon = (con(:,2) - con(:,1)) ./ (con(:,2) + con(:,1));
rdLow = (low(:,2) - low(:,1)) ./ (low(:,2) + low(:,1));
rdHigh = (high(:,2) - high(:,1)) ./ (high(:,2) + high(:,1));

% take absolute value
rdConAbs = abs(rdCon);
rdLowAbs = abs(rdLow);
rdHighAbs = abs(rdHigh);


%% plot results as bar graph
hFig_bar = figure;
xVals = 1:3;
medianVals = [nanmedian(rdConAbs),nanmedian(rdLowAbs),nanmedian(rdHighAbs)];

% calculate SEM (standard deviation divided by square root of number of cells)
% NB:   must ignore nans!
errorVals = [(nanstd(rdConAbs)) ./ (sqrt(sum(~isnan(rdConAbs)))), ...
    (nanstd(rdLowAbs)) ./ (sqrt(sum(~isnan(rdLowAbs)))), ...
    (nanstd(rdHighAbs)) ./ (sqrt(sum(~isnan(rdHighAbs))))];

bar(xVals,medianVals,'facecolor',[0.5 0.5 0.5])   % RGB values (gray here)
hold on
errorbar(xVals,medianVals,errorVals,'k.','linewidth',2)
hold off

ax = gca;
ax.XTick = 1:3;
ax.XTickLabel = doseNames;
ax.FontSize = 14;
ax.Box = 'off';
xlabel 'CNO dose (mg/kg)'
ylabel 'Absolute rate difference score'
title 'Rate changes by dose in CA1 place cells'

% add N for each bar
nCounts = [sum(~isnan(rdConAbs)), ...
    sum(~isnan(rdLowAbs)), ...
    sum(~isnan(rdHighAbs))];
textYlocs = medianVals / 2;   % halfway up the bars
for iGroup = 1:numel(medianVals)
    text(xVals(iGroup),textYlocs(iGroup),['n = ' num2str(nCounts(iGroup))],'horizontalalignment','center')
end


%% plot results as beehive to see distribution of data points
hFig_beehive = figure;
plotSpread({rdConAbs rdLowAbs rdHighAbs})

ax = gca;
ax.XTick = 1:3;
ax.XTickLabel = doseNames;
ax.FontSize = 14;
ax.Box = 'off';
xlabel 'CNO dose (mg/kg)'
ylabel 'Absolute rate difference score'
title 'Rate changes by dose in CA1 place cells'

% increase marker size
hMarkers = findobj(gca,'type','line');   % find all line objects (3 groups of dots in this case)
hMarkers = flipud(hMarkers);   % flip the order of the handles (by default they are in order of most recently plotted)
set(hMarkers,'markersize',15)

% set unique marker color for each group
markerColors = {'k','b','r'};
for iGroup = 1:numel(hMarkers)
    set(hMarkers(iGroup),'color',markerColors{iGroup})
end

% add median values as green diamonds
hold on
plot(xVals,medianVals,'gd','markerfacecolor','g','markersize',15)
hold off
drawnow


%% run stats

% test normality of each distribution using the Lilliefors test
normTest = [];
normTest(1) = lillietest(rdConAbs);
normTest(2) = lillietest(rdLowAbs);
normTest(3) = lillietest(rdHighAbs);

pVals = [];
if sum(normTest)   % this is true if any of the null hypotheses were rejected
    display('Failed normality test, using nonparametric statistics...')
    pVals(1) = ranksum(rdLowAbs,rdConAbs,'tail','right');
    pVals(2) = ranksum(rdHighAbs,rdConAbs,'tail','right');
    pVals(3) = ranksum(rdHighAbs,rdLowAbs,'tail','right');
    % NB:  these are one-sided tests (see ranksum doc) b/c we only want to know if more CNO means
    %      more rate change. remove last 2 arguments to run a two-sided test (default).
    %      also note that these are independent tests, use signrank for paired tests.
else
    display('Passed normality test, using parametric statistics...')
    [~,pVals(1)] = ttest2(rdLowAbs,rdConAbs,'tail','right');
    [~,pVals(2)] = ttest2(rdHighAbs,rdConAbs,'tail','right');
    [~,pVals(3)] = ttest2(rdHighAbs,rdLowAbs,'tail','right');
    % NB:  these are one-sided tests (see ttest2 doc) b/c we only want to know if more CNO means
    %      more rate change. remove last 2 arguments to run a two-sided test (default).
    %      also note that these are independent tests, use ttest for paired tests.
end

display(sprintf('0.5 mg/kg vs. 0 mg/kg:  p = %.4e',pVals(1)))
display(sprintf('15 mg/kg vs. 0 mg/kg:   p = %.4e',pVals(2)))
display(sprintf('15 mg/kg vs. 0.5 mg/kg: p = %.4e\n',pVals(3)))


%% save figures

% choose directory to save in
saveDir = uigetdir('','Select output folder');

% create filenames (sets file type as well)
dt = datestr(clock,30);   % get current time to have unique file name every time you save
barName = [saveDir '\exampleBar_' dt '.jpg'];
beehiveName = [saveDir '\exampleBeehive_' dt '.pdf'];

saveas(hFig_bar,barName)
saveas(hFig_beehive,beehiveName)

display(sprintf('Saved bar plot as:      %s',barName))
display(sprintf('Saved beehive plot as:  %s',beehiveName))


%% save results
dataName = [saveDir '\exampleResults_ ' dt '.mat'];
save(dataName,'medianVals','pVals')

display(sprintf('Saved results as:       %s',dataName))


