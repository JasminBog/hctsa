function TS_init(INP_ts,INP_mops,INP_ops,beVocal,outputFile)
% TS_init       Takes in time series, master operation, and operation input
% files and produces a formatted HCTSA .mat file
%
% This function is used instead to run hctsa analysis without a linked mySQL database.
%
%---INPUTS:
% INP_ts: A time-series input file
% INP_mops: A master operations input file
% INP_ops: An operations input file
% beVocal: Whether to display details of the progress of the script to screen
% outputFile: Specify an alternative output filename
%
%---OUTPUTS:
% Writes output into HCTSA_loc.mat (or specified custom filename)

% ------------------------------------------------------------------------------
% Copyright (C) 2015, Ben D. Fulcher <ben.d.fulcher@gmail.com>,
% <http://www.benfulcher.com>
%
% If you use this code for your research, please cite:
% B. D. Fulcher, M. A. Little, N. S. Jones, "Highly comparative time-series
% analysis: the empirical structure of time series and their methods",
% J. Roy. Soc. Interface 10(83) 20130048 (2010). DOI: 10.1098/rsif.2013.0048
%
% This work is licensed under the Creative Commons
% Attribution-NonCommercial-ShareAlike 4.0 International License. To view a copy of
% this license, visit http://creativecommons.org/licenses/by-nc-sa/4.0/ or send
% a letter to Creative Commons, 444 Castro Street, Suite 900, Mountain View,
% California, 94041, USA.
% ------------------------------------------------------------------------------

% ------------------------------------------------------------------------------
% Check Inputs:
% ------------------------------------------------------------------------------

if nargin < 1 || isempty(INP_ts)
    error('Please supply a formatted time-series input file (see documentation for details).');
end
if nargin < 2 || isempty(INP_mops)
    INP_mops = 'INP_mops.txt';
end
if nargin < 3 || isempty(INP_ops)
    INP_ops = 'INP_ops.txt';
end
if nargin < 4
    beVocal = 0; % by default do your business in peace
end
if nargin < 5
    outputFile = 'HCTSA_loc.mat';
end

% ------------------------------------------------------------------------------
% First check if you're about to overwrite an existing file
% ------------------------------------------------------------------------------
if exist(['./',outputFile],'file')
    reply = input(sprintf(['Warning: %s already exists -- if you continue, this ' ...
        'file will be overwritten.\n[press ''y'' to continue]'],outputFile),'s');
    if ~strcmp(reply,'y')
        return
    end
end

% ------------------------------------------------------------------------------
% Get time series, operations, master operations into structure arrays
% and assign IDs
% ------------------------------------------------------------------------------
TimeSeries = SQL_add('ts', INP_ts, 0, beVocal);
% Assign IDs:
numTS = length(TimeSeries);
for i = 1:numTS
    TimeSeries(i).ID = i;
end

MasterOperations = SQL_add('mops', INP_mops, 0, beVocal)';
numMops = length(MasterOperations);
% Assign IDs:
for i = 1:numMops
    MasterOperations(i).ID = i;
end

Operations = SQL_add('ops', INP_ops, 0, beVocal);
numOps = length(Operations);
% Assign IDs:
for i = 1:numOps
    Operations(i).ID = i;
end

% ------------------------------------------------------------------------------
% Match operations to a master ID
% ------------------------------------------------------------------------------
for i = 1:numOps
    theMasterMatch = strcmp(Operations(i).Label,{MasterOperations.Label});
    if sum(theMasterMatch)==0
        error('No master match for operation: %s',Operations(i).Name);
    end
    Operations(i).MasterID = MasterOperations(theMasterMatch).ID;
end

% No longer need the label field
Operations = removeField(Operations,'Label');

%-------------------------------------------------------------------------------
% Check that all master operations are required
%-------------------------------------------------------------------------------
mastersNeeded = ismember([MasterOperations.ID],[Operations.MasterID]);
if ~all(mastersNeeded)
    warning(sprintf(['%u/%u master operations are not used by the %u operations' ...
                         ' and will be removed.'],...
                        sum(~mastersNeeded),numMops,numOps));
    MasterOperations = MasterOperations(mastersNeeded);
    numMops = sum(mastersNeeded);
end

% ------------------------------------------------------------------------------
% Generate the TS_DataMat, TS_Quality, and TS_CalcTime matrices
% ------------------------------------------------------------------------------
% All NaNs -> NULL (haven't yet been calculated)
TS_DataMat = ones(numTS,numOps)*NaN;
TS_Quality = ones(numTS,numOps)*NaN;
TS_CalcTime = ones(numTS,numOps)*NaN;

% ------------------------------------------------------------------------------
% Save to file
% ------------------------------------------------------------------------------
% Set a flag, fromDatabase, that tells you that you that this was generated by
% TS_init and shouldn't be written back to a database
fromDatabase = 0;
save(outputFile,'TimeSeries','Operations','MasterOperations',...
            'TS_DataMat','TS_Quality','TS_CalcTime','fromDatabase','-v7.3');

fprintf(1,'Successfully initialized %s with %u time series, %u master operations, and %u operations\n',...
                        outputFile,numTS,numMops,numOps);

% ------------------------------------------------------------------------------
function newStructArray = removeField(oldStructArray,fieldToRemove)

    theFieldNames = fieldnames(oldStructArray);

    fieldInd = strcmp(theFieldNames,fieldToRemove);

    oldCell = squeeze(struct2cell(oldStructArray));

    newCell = oldCell(~fieldInd,:);

    newStructArray = cell2struct(newCell,theFieldNames(~fieldInd));
end
% ------------------------------------------------------------------------------

end
