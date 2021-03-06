
% Return length of recording session.
%
%   USAGE
%       minions.sessionLength
%
% Written by BRK 2016

function sessionLength

folder = uigetdir('','Select recording session');
fileEnding = dir(fullfile(folder,'*.nvt'));
filename = fullfile(folder,fileEnding.name);
[TimeStamps,ExtractedX,ExtractedY,ExtractedAngle,Targets,Points,Header] = Nlx2MatVT(filename,[1 1 1 1 1 1],1,1);
display(sprintf('Recording is %.0f mins',length(TimeStamps)/25/60));