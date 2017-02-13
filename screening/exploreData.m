
% Load data from a recording session with BNT so that all BNT functions are ready to use.
%
%   USAGE
%       exploreData
%
%   NOTES
%       This function is bare bones by design so that the user can add whatever information is relevant to them.
%
% Written by BRK 2017

function exploreData

%% get globals
global penguinInput arena clusterFormat

%% choose recording session and load the data
folder = uigetdir();
cd(folder)
writeInputBNT(penguinInput,folder,arena,clusterFormat)
data.loadSessions(penguinInput)

%% plot animal's trajectory
figure;
hold on
pathTrialBRK('color',[.5 .5 .5])
axis off

%% display cluster list
clusterList = data.getCells;
display(clusterList)